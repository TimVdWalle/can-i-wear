import Foundation
import Testing
@testable import Can_I_Wear

@MainActor
struct RecommendationLoadDiagnosticsTests {
    private let now = ItemEngineFixtures.dayEnd.addingTimeInterval(-3 * 3_600)
    private let location = LocationIdentity(latitude: 50.85, longitude: 4.35)

    @Test func enablingAfterLiveLoadRestoresContextWithoutReloadingOrChangingState() async throws {
        let context = makeContext(enabled: false)
        defer { context.defaults.removePersistentDomain(forName: context.suite) }
        let weather = DiagnosticCountingWeather(forecast: forecast())
        let model = makeModel(context.diagnostics, store: MemoryCacheDataStore(), weather: weather)
        await model.loadIfNeeded()
        let original = model.state
        #expect(context.diagnostics.events.isEmpty)
        context.defaults.set(true, forKey: DebugSettings.enabledKey)
        model.refreshDebugSetting()

        #expect(model.state == original)
        #expect(await weather.requestCount == 1)
        #expect(context.diagnostics.locationSummary?.source == "Live device location")
        #expect(context.diagnostics.weatherSummary?.trigger == "Live refresh after location resolution")
        #expect(context.diagnostics.weatherSummary?.outcome == "Success")
        #expect(context.diagnostics.weatherSummary?.durationSeconds == 0)
        #expect(context.diagnostics.hourlyDetails.count == 3)
        #expect(context.diagnostics.events.filter { $0.category != .place }.map(\.title)
            == ["Debug enabled", "Recommendation periods"])

        context.defaults.set(false, forKey: DebugSettings.enabledKey)
        model.refreshDebugSetting()
        #expect(context.diagnostics.events.isEmpty)
        #expect(context.diagnostics.weatherSummary == nil)
        #expect(model.state == original)
        context.defaults.set(true, forKey: DebugSettings.enabledKey)
        model.refreshDebugSetting()
        #expect(context.diagnostics.weatherSummary?.outcome == "Success")
        #expect(await weather.requestCount == 1)
    }

    @Test func liveLoadPreservesOrderedEventsAndMeasurementContext() async {
        let context = makeContext(enabled: true)
        defer { context.defaults.removePersistentDomain(forName: context.suite) }
        let model = makeModel(context.diagnostics, store: MemoryCacheDataStore(), weather: FixedWeatherProvider(result: .success(forecast())))
        await model.loadIfNeeded()
        let events = context.diagnostics.events.filter { $0.category != .place }
        #expect(events.map(\.title) == [
            "Recommendation load", "Location cache", "Location request", "Location request",
            "Weather cache", "Weather request", "Weather request", "Recommendation periods", "Weather cache save"
        ])
        #expect(events.map(\.outcome) == [.started, .rejected, .started, .success, .rejected, .started, .success, .success, .success])
        #expect(events[1].detail == "No saved location exists.")
        #expect(events[2].detail == "Requested because the cache was not reusable: No saved location exists.")
        #expect(events[3].durationSeconds == 0)
        #expect(events[5].detail == "App load requested live weather. Timeout: 10 s.")
        #expect(events[6].durationSeconds == 0)
        #expect(context.diagnostics.locationSummary?.cacheStatus == "New reading • No saved location")
        #expect(context.diagnostics.weatherSummary?.provider == "FixedWeatherProvider")
    }

    @Test func enablingAfterFreshCacheReuseRestoresSkippedRefreshContext() async {
        let context = makeContext(enabled: false)
        defer { context.defaults.removePersistentDomain(forName: context.suite) }
        let store = MemoryCacheDataStore()
        await LocationCache(store: store).save(reading())
        await WeatherCache(store: store).save(forecast())
        let weather = DiagnosticCountingWeather(forecast: forecast())
        let model = makeModel(context.diagnostics, store: store, weather: weather)
        await model.loadIfNeeded()
        let original = model.state
        context.defaults.set(true, forKey: DebugSettings.enabledKey)
        model.refreshDebugSetting()
        #expect(model.state == original)
        #expect(await weather.requestCount == 0)
        #expect(context.diagnostics.locationSummary?.source == "Location cache")
        #expect(context.diagnostics.weatherSummary?.outcome == "Refresh skipped")
        #expect(context.diagnostics.weatherSummary?.cacheStatus == "Used; less than 1 minute old; refresh skipped")
        #expect(context.diagnostics.weatherSummary?.durationSeconds == nil)
    }

    @Test func reporterRestoresOnlyTheCallersCurrentForecastAndRecomputesLocationAge() {
        let context = makeContext(enabled: false)
        defer { context.defaults.removePersistentDomain(forName: context.suite) }
        let reporter = makeReporter(context.diagnostics)
        #expect(!reporter.refreshSetting(forecast: nil, at: now))
        reporter.reusedLocation(reading(), age: 0)
        reporter.liveWeatherReceived(forecast(), duration: 2)
        context.defaults.set(true, forKey: DebugSettings.enabledKey)
        #expect(reporter.refreshSetting(forecast: forecast(), at: now.addingTimeInterval(60)))
        #expect(context.diagnostics.locationSummary?.ageSeconds == 60)
        #expect(context.diagnostics.weatherSummary?.durationSeconds == 2)
        let events = context.diagnostics.events
        #expect(!reporter.refreshSetting(forecast: forecast(), at: now))
        #expect(context.diagnostics.events == events)

        context.defaults.set(false, forKey: DebugSettings.enabledKey)
        #expect(!reporter.refreshSetting(forecast: nil, at: now))
        context.defaults.set(true, forKey: DebugSettings.enabledKey)
        #expect(reporter.refreshSetting(forecast: nil, at: now))
        #expect(context.diagnostics.weatherSummary == nil, "A discarded mismatched forecast must not be restored by diagnostic context")
    }

    @Test func requestAndCooldownReportingPreservesMessagesAndInjectedConfiguration() {
        let context = makeContext(enabled: true)
        defer { context.defaults.removePersistentDomain(forName: context.suite) }
        let config = ReusePolicyConfig(
            locationFreshness: 1, weatherRefreshInterval: 120, weatherFreshness: 240,
            maximumForecastDistanceMeters: 5, weatherRequestTimeout: .milliseconds(1_250), failedRequestCooldown: 7
        )
        let reporter = makeReporter(context.diagnostics, config: config)
        reporter.manualRefreshBlocked()
        reporter.manualRefreshBlocked(remaining: 2.1)
        reporter.retryBlocked()
        reporter.retryBlocked(remaining: 3.1)
        reporter.manualRefreshStarted()
        reporter.retryRequested()
        reporter.loadStarted(trigger: "Retry")
        reporter.locationRequestStarted(cacheRejection: nil)
        reporter.acquiredLocation(reading(), cacheRejection: nil, at: now.addingTimeInterval(1), duration: 0.5)
        reporter.locationFailed("Permission denied", duration: 2)
        reporter.weatherRequestStarted(trigger: "Retry")
        reporter.weatherFailed("Request cancelled", duration: 3)
        reporter.retryCooldown()
        let events = context.diagnostics.events
        #expect(events.map(\.title) == [
            "Manual refresh blocked", "Manual refresh blocked", "Retry blocked", "Retry blocked",
            "Manual refresh started", "Retry requested", "Recommendation load", "Location request",
            "Location request", "Location request", "Weather request", "Weather request", "Retry cooldown"
        ])
        #expect(events[0].detail == "A location or weather request is already running.")
        #expect(events[1].detail == "Available in 3 seconds after the previous failure.")
        #expect(events[2].detail == "A request is already running.")
        #expect(events[3].detail == "Available in 4 seconds.")
        #expect(events[7].detail == "Pull-to-refresh requires a new device fix instead of saved location.")
        #expect(events[8].durationSeconds == 0.5)
        #expect(events[9].category == .error && events[9].durationSeconds == 2)
        #expect(events[10].detail == "Retry requested live weather. Timeout: \(RecommendationDiagnosticText.durationText(1.25)).")
        #expect(events[11].outcome == .failed && events[11].durationSeconds == 3)
        #expect(events[12].detail == "Another retry is available in 7 seconds.")
        #expect(context.diagnostics.locationSummary?.cacheStatus == "New reading • Saved location bypassed for pull-to-refresh")
        #expect(context.diagnostics.locationSummary?.ageSeconds == 1)
    }

    @Test func cacheAndFallbackReportingPreservesMetadataAndFailureContext() {
        let context = makeContext(enabled: true)
        defer { context.defaults.removePersistentDomain(forName: context.suite) }
        let reporter = makeReporter(context.diagnostics)
        reporter.liveWeatherReceived(forecast(), duration: 2)
        reporter.cachedWeatherFound(forecast(), age: 1_200, distance: 100)
        #expect(context.diagnostics.weatherSummary?.outcome == "Usable saved forecast")
        #expect(context.diagnostics.weatherSummary?.durationSeconds == nil)
        #expect(context.diagnostics.weatherSummary?.cacheStatus == "20 minutes old; location separation 100 m")
        reporter.weatherRefreshSkipped(forecast(), age: 120)
        #expect(context.diagnostics.events.last?.detail == "2 minutes old; refresh skipped because weather is current for 15 minutes.")
        reporter.cachedWeatherRefreshing(age: 1_200, isManual: true)
        #expect(context.diagnostics.events.last?.detail == "20 minutes old; manual refresh started.")
        reporter.cachedWeatherRefreshing(age: 1_200, isManual: false)
        #expect(context.diagnostics.events.last?.detail == "20 minutes old; background refresh started.")
        reporter.weatherCacheExpired(age: 5_401, distance: 100)
        #expect(context.diagnostics.events.last?.detail == "Rejected at 90 minutes old because the 90 minutes usable limit was exceeded; location separation 100 m.")
        reporter.weatherCacheUnavailable(.malformed)
        #expect(context.diagnostics.events.last?.detail == "The saved forecast could not be decoded.")
        reporter.selectedItemForecastUnavailable()
        #expect(context.diagnostics.events.last?.category == .evaluation)
        #expect(context.diagnostics.events.last?.outcome == .failed)
        reporter.fallbackExpired()
        #expect(context.diagnostics.events.last?.detail == "The saved forecast crossed the 90 minutes limit while the request was running.")
        reporter.reusedFallback(forecast(), age: 1_200)
        #expect(context.diagnostics.weatherSummary?.outcome == "Reused cached forecast")
        #expect(context.diagnostics.weatherSummary?.durationSeconds == nil)
        #expect(context.diagnostics.events.last?.detail == "Refresh failed; retained the 20 minutes-old saved forecast. Manual refresh is available again in 30 seconds.")
        reporter.weatherExpired()
        #expect(context.diagnostics.events.last?.detail == "The displayed saved forecast crossed the 90 minutes usable limit.")
        reporter.weatherSaved()
        #expect(context.diagnostics.events.last?.title == "Weather cache save")
        #expect(context.diagnostics.events.last?.outcome == .success)
    }

    @Test func evaluationReportingUsesSuppliedOutputAndClearsUnavailableJacketDetails() throws {
        let context = makeContext(enabled: true)
        defer { context.defaults.removePersistentDomain(forName: context.suite) }
        let reporter = makeReporter(context.diagnostics)
        let builder = RecommendationPresentationBuilder()
        let output = try #require(builder.build(
            from: forecast(), for: [.leatherJacket], at: now, isUsingSavedWeather: false,
            isRefreshing: false, refreshFailed: false, refreshAvailableAt: now
        ))
        reporter.evaluated(output, forecast: forecast())
        #expect(context.diagnostics.hourlyDetails.count == 3)
        #expect(context.diagnostics.events.last?.detail == "Evaluated 3 remaining hours; 1 of 1 selected items have daily advice. Jacket diagnostics retain their own protective policy.")
        reporter.clearEvaluation()
        #expect(context.diagnostics.hourlyDetails.isEmpty)
        reporter.evaluated(output, forecast: forecast())
        let noJacket = NormalizedForecast(
            hours: (0..<3).map { ItemEngineFixtures.hour(at: now.addingTimeInterval(Double($0) * 3_600), actual: nil) },
            metadata: forecast().metadata
        )
        let independent = try #require(builder.build(
            from: noJacket, for: [.raincoat], at: now, isUsingSavedWeather: false,
            isRefreshing: false, refreshFailed: false, refreshAvailableAt: now
        ))
        reporter.evaluated(independent, forecast: noJacket)
        #expect(context.diagnostics.hourlyDetails.isEmpty)
        #expect(context.diagnostics.periodDetails.isEmpty)
        reporter.evaluationFailed()
        #expect(context.diagnostics.events.last?.detail == "Timezone or remaining-day coverage requirements were not met.")
        #expect(context.diagnostics.events.last?.outcome == .failed)
    }

    private func makeReporter(_ diagnostics: DebugDiagnostics, config: ReusePolicyConfig = AppConfiguration.reusePolicy) -> RecommendationLoadDiagnostics {
        RecommendationLoadDiagnostics(diagnostics: diagnostics, providerName: "Fixture", config: config)
    }

    private func makeContext(enabled: Bool) -> (defaults: UserDefaults, suite: String, diagnostics: DebugDiagnostics) {
        let suite = "RecommendationLoadDiagnosticsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(enabled, forKey: DebugSettings.enabledKey)
        return (defaults, suite, DebugDiagnostics(
            settings: DebugSettings(defaults: defaults), eventStore: LoadDiagnosticEventStore(),
            placeResolver: LoadDiagnosticPlaceResolver(), maximumEvents: 100, now: { self.now }
        ))
    }

    private func makeModel(_ diagnostics: DebugDiagnostics, store: MemoryCacheDataStore, weather: any WeatherProvider) -> RecommendationViewModel {
        RecommendationViewModel(
            locationProvider: FixedLocationProvider(result: .success(reading())), weatherProvider: weather,
            locationCache: LocationCache(store: store), weatherCache: WeatherCache(store: store),
            diagnostics: diagnostics, localityResolver: LoadDiagnosticLocalityResolver(), now: { self.now }
        )
    }

    private func reading() -> LocationReading {
        LocationReading(identity: location, accuracyMeters: 10, timestamp: now)
    }

    private func forecast() -> NormalizedForecast {
        NormalizedForecast(
            hours: (0..<3).map { ItemEngineFixtures.hour(at: now.addingTimeInterval(Double($0) * 3_600)) },
            metadata: ForecastMetadata(fetchedAt: now, location: location)
        )
    }
}

private actor DiagnosticCountingWeather: WeatherProvider {
    let forecast: NormalizedForecast
    private(set) var requestCount = 0
    init(forecast: NormalizedForecast) { self.forecast = forecast }
    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        requestCount += 1
        return forecast
    }
}

@MainActor private final class LoadDiagnosticEventStore: DiagnosticEventPersisting {
    func load() -> [DiagnosticEvent] { [] }
    func save(_ events: [DiagnosticEvent]) {}
    func clear() {}
}

@MainActor private struct LoadDiagnosticPlaceResolver: PlaceResolving {
    func place(for location: LocationIdentity) async -> String? { "Test place" }
}

@MainActor private struct LoadDiagnosticLocalityResolver: LocalityResolving {
    func locality(for location: LocationIdentity) async -> String? { "Test locality" }
}
