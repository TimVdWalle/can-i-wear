import Foundation
import Testing
@testable import Can_I_Wear

@MainActor
struct DebugDiagnosticsTests {
    private let now = Date(timeIntervalSince1970: 1_791_203_400)
    private let currentHour = Date(timeIntervalSince1970: 1_791_201_600)
    private let location = LocationIdentity(latitude: 50.85, longitude: 4.35)

    @Test func debugDefaultsOffBoundsHistoryAndClearsWhenDisabled() {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = DebugSettings(defaults: defaults)
        let store = MemoryDiagnosticEventStore()
        let diagnostics = DebugDiagnostics(
            settings: settings,
            eventStore: store,
            placeResolver: FixedPlaceResolver(place: nil),
            now: { self.now }
        )

        #expect(!diagnostics.isEnabled)
        diagnostics.record(
            category: .session,
            outcome: .information,
            title: "Ignored",
            detail: "Debug is off"
        )
        #expect(diagnostics.events.isEmpty)

        defaults.set(true, forKey: DebugSettings.enabledKey)
        diagnostics.refreshSetting()
        for index in 0..<25 {
            diagnostics.record(
                category: .weather,
                outcome: .information,
                title: "Event \(index)",
                detail: "Bounded local event"
            )
        }

        #expect(diagnostics.events.count == 20)
        #expect(diagnostics.events.first?.title == "Event 5")
        #expect(store.persisted == diagnostics.events)

        defaults.set(false, forKey: DebugSettings.enabledKey)
        diagnostics.refreshSetting()

        #expect(!diagnostics.isEnabled)
        #expect(diagnostics.events.isEmpty)
        #expect(store.persisted.isEmpty)
        #expect(diagnostics.locationSummary == nil)
        #expect(diagnostics.weatherSummary == nil)
    }

    @Test func readableReportIncludesPlaceInputsWindDecisionsPeriodsAndEvents() async {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: DebugSettings.enabledKey)
        let diagnostics = DebugDiagnostics(
            settings: DebugSettings(defaults: defaults),
            eventStore: MemoryDiagnosticEventStore(),
            placeResolver: FixedPlaceResolver(place: "Wetstraat, Brussels"),
            now: { self.now }
        )
        let reading = LocationReading(identity: location, accuracyMeters: 25, timestamp: now)
        diagnostics.updateLocation(
            reading,
            source: "Live device location",
            ageSeconds: 0,
            cacheStatus: "Fetched because no saved location exists"
        )
        for _ in 0..<5 { await Task.yield() }

        let hour = HourlyWeather(
            timestamp: currentHour,
            timezoneIdentifier: "Europe/Brussels",
            actualTemperatureCelsius: 12,
            apparentTemperatureCelsius: 10,
            precipitationAmountMillimeters: 0,
            precipitationType: PrecipitationType.none,
            precipitationChanceFraction: 0,
            fogOrMistCondition: FogOrMistCondition.none,
            windSpeedKilometersPerHour: 12,
            windGustKilometersPerHour: 25
        )
        let forecast = NormalizedForecast(
            hours: [hour],
            metadata: ForecastMetadata(fetchedAt: now, location: location)
        )
        let recommendation = HourlyRecommendation(level: .okay, reason: .suitableTemperature)
        let evaluation = DailyEvaluation(
            interval: DateInterval(start: currentHour, duration: 3_600),
            timezoneIdentifier: "Europe/Brussels",
            hours: [EvaluatedHour(timestamp: currentHour, recommendation: recommendation)]
        )
        let periods = [DayPeriod(
            interval: evaluation.interval,
            timezoneIdentifier: evaluation.timezoneIdentifier,
            recommendation: recommendation
        )]
        diagnostics.updateWeather(
            forecast,
            provider: "Open-Meteo",
            trigger: "Live refresh",
            outcome: "Success",
            durationSeconds: 0.4,
            cacheStatus: "Saved"
        )
        diagnostics.updateEvaluation(forecast: forecast, evaluation: evaluation, periods: periods)
        diagnostics.record(
            category: .evaluation,
            outcome: .success,
            title: "Recommendation periods",
            detail: "One period"
        )

        let report = diagnostics.readableReport
        #expect(report.contains("Place (included in copied report): Wetstraat, Brussels"))
        #expect(report.contains("Provider: Open-Meteo"))
        #expect(report.contains("wind 12 km/h, gust 25 km/h"))
        #expect(report.contains("decision wear (suitable temperature)"))
        #expect(report.contains("FINAL PERIODS"))
        #expect(report.contains("[evaluation/success]"))
        #expect(!report.contains("50.85"))
    }

    @Test func debugEnabledDoesNotChangeRecommendation() async {
        let forecast = completeForecast()
        let offDiagnostics = makeDiagnostics(enabled: false)
        let onDiagnostics = makeDiagnostics(enabled: true)
        let offStore = MemoryCacheDataStore()
        let onStore = MemoryCacheDataStore()
        let locationReading = LocationReading(identity: location, accuracyMeters: 25, timestamp: now)

        let offModel = RecommendationViewModel(
            locationProvider: FixedLocationProvider(result: .success(locationReading)),
            weatherProvider: FixedWeatherProvider(result: .success(forecast)),
            locationCache: LocationCache(store: offStore),
            weatherCache: WeatherCache(store: offStore),
            diagnostics: offDiagnostics,
            now: { self.now }
        )
        let onModel = RecommendationViewModel(
            locationProvider: FixedLocationProvider(result: .success(locationReading)),
            weatherProvider: FixedWeatherProvider(result: .success(forecast)),
            locationCache: LocationCache(store: onStore),
            weatherCache: WeatherCache(store: onStore),
            diagnostics: onDiagnostics,
            now: { self.now }
        )

        await offModel.loadIfNeeded()
        await onModel.loadIfNeeded()

        #expect(offModel.state == onModel.state)
        #expect(offDiagnostics.events.isEmpty)
        #expect(!onDiagnostics.events.isEmpty)
        #expect(onDiagnostics.hourlyDetails.contains { $0.contains("wind 80 km/h") })
    }

    @Test func timeoutAndFreshCacheFallbackProduceExplainableEventSequence() async {
        let diagnostics = makeDiagnostics(enabled: true)
        let store = MemoryCacheDataStore()
        let reading = LocationReading(identity: location, accuracyMeters: 25, timestamp: now)
        await LocationCache(store: store).save(reading)
        await WeatherCache(store: store).save(completeForecast())
        let model = RecommendationViewModel(
            locationProvider: FixedLocationProvider(result: .success(reading)),
            weatherProvider: SlowDiagnosticWeatherProvider(),
            locationCache: LocationCache(store: store),
            weatherCache: WeatherCache(store: store),
            diagnostics: diagnostics,
            now: { self.now },
            sleep: { _ in }
        )

        await model.loadIfNeeded()

        #expect(model.state.result?.cachedAge == 0)
        #expect(diagnostics.events.contains {
            $0.title == "Weather request" && $0.detail == "Request timed out"
        })
        #expect(diagnostics.events.contains {
            $0.title == "Weather fallback" && $0.outcome == .reused
        })
        #expect(diagnostics.weatherSummary?.outcome == "Reused cached forecast")
    }

    @Test func missingPlaceFallsBackWithoutBlockingOrExposingCoordinates() async {
        let diagnostics = makeDiagnostics(enabled: true, place: nil)
        diagnostics.updateLocation(
            LocationReading(identity: location, accuracyMeters: 25, timestamp: now),
            source: "Location cache",
            ageSeconds: 0,
            cacheStatus: "Fresh"
        )
        for _ in 0..<5 { await Task.yield() }

        #expect(diagnostics.place == "City or region unavailable")
        #expect(diagnostics.events.contains {
            $0.title == "Place lookup" && $0.outcome == .failed
        })
        #expect(!diagnostics.readableReport.contains("50.85"))
    }

    private func makeDiagnostics(enabled: Bool, place: String? = "Brussels") -> DebugDiagnostics {
        let (defaults, _) = isolatedDefaults()
        defaults.set(enabled, forKey: DebugSettings.enabledKey)
        return DebugDiagnostics(
            settings: DebugSettings(defaults: defaults),
            eventStore: MemoryDiagnosticEventStore(),
            placeResolver: FixedPlaceResolver(place: place),
            now: { self.now }
        )
    }

    private func completeForecast() -> NormalizedForecast {
        NormalizedForecast(
            hours: (0..<10).map { offset in
                HourlyWeather(
                    timestamp: currentHour.addingTimeInterval(TimeInterval(offset * 3_600)),
                    timezoneIdentifier: "Europe/Brussels",
                    actualTemperatureCelsius: 12,
                    apparentTemperatureCelsius: 12,
                    precipitationAmountMillimeters: 0,
                    precipitationType: PrecipitationType.none,
                    precipitationChanceFraction: 0,
                    windSpeedKilometersPerHour: 80,
                    windGustKilometersPerHour: 120
                )
            },
            metadata: ForecastMetadata(fetchedAt: now, location: location)
        )
    }

    private func isolatedDefaults() -> (UserDefaults, String) {
        let suite = "DebugDiagnosticsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (defaults, suite)
    }
}

private struct SlowDiagnosticWeatherProvider: WeatherProvider {
    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        try await Task.sleep(for: .seconds(60))
        throw WeatherProviderError.unavailable
    }
}

private extension RecommendationViewModel.State {
    var result: DailyRecommendationPresentation? {
        guard case .result(let result) = self else { return nil }
        return result
    }
}

@MainActor
private final class MemoryDiagnosticEventStore: DiagnosticEventPersisting {
    private(set) var persisted: [DiagnosticEvent] = []

    func load() -> [DiagnosticEvent] { persisted }
    func save(_ events: [DiagnosticEvent]) { persisted = events }
    func clear() { persisted = [] }
}

@MainActor
private struct FixedPlaceResolver: PlaceResolving {
    let place: String?

    func place(for location: LocationIdentity) async -> String? { place }
}
