import Foundation
import Testing
@testable import Can_I_Wear

@MainActor
struct RecommendationViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_791_203_400)
    private let currentHour = Date(timeIntervalSince1970: 1_791_201_600)
    private let location = LocationIdentity(latitude: 50.85, longitude: 4.35)

    @Test func mapsSuccessfulWearCautionAndAvoidResults() async {
        let wear = makeModel(forecast: forecast())
        let caution = makeModel(forecast: forecast(chance: 0.10))
        let avoid = makeModel(forecast: forecast(amount: 1))
        let fog = makeModel(forecast: forecast(fogOrMist: .fog))

        await wear.loadIfNeeded()
        await caution.loadIfNeeded()
        await avoid.loadIfNeeded()
        await fog.loadIfNeeded()

        #expect(wear.state.result?.periods.first?.recommendation.title == "Wear")
        #expect(caution.state.result?.periods.first?.recommendation.title == "Maybe")
        #expect(avoid.state.result?.periods.first?.recommendation.title == "Don’t wear")
        #expect(avoid.state.result?.periods.first?.recommendation.reason.contains("damage leather") == true)
        #expect(fog.state.result?.periods.first?.recommendation.title == "Don’t wear")
        #expect(fog.state.result?.periods.first?.recommendation.reason == "Fog is expected.")
    }

    @Test func representsLocationAndWeatherFailuresExplicitly() async {
        let deniedStore = MemoryCacheDataStore()
        let denied = RecommendationViewModel(
            locationProvider: FixedLocationProvider(result: .failure(.permissionDenied)),
            weatherProvider: FixedWeatherProvider(result: .failure(.unavailable)),
            locationCache: LocationCache(store: deniedStore),
            weatherCache: WeatherCache(store: deniedStore),
            now: { self.now }
        )
        let weatherStore = MemoryCacheDataStore()
        let weatherFailure = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: FixedWeatherProvider(result: .failure(.network)),
            locationCache: LocationCache(store: weatherStore),
            weatherCache: WeatherCache(store: weatherStore),
            now: { self.now }
        )

        await denied.loadIfNeeded()
        await weatherFailure.loadIfNeeded()

        #expect(denied.state == .locationPermissionDenied)
        #expect(weatherFailure.state == .weatherUnavailable)
    }

    @Test func representsIncompleteForecastWithoutInventingAResult() async {
        let model = makeModel(forecast: forecast().replacingHours(with: []))

        await model.loadIfNeeded()

        #expect(model.state == .forecastIncomplete)
    }

    @Test func presentsMaterialWeatherChangesAsOrderedPeriods() async {
        let model = makeModel(forecast: forecast(amounts: [1, 1, 1, 0, 0, 0, 0, 0, 0, 0]))

        await model.loadIfNeeded()

        #expect(model.state.result?.periods.map(\.recommendation.title) == ["Don’t wear", "Wear"])
        #expect(model.state.result?.periods[0].interval.end == model.state.result?.periods[1].interval.start)
    }

    @Test func presentsExplicitFogAsAnAvoidPeriod() async {
        let fogConditions: [FogOrMistCondition] = [
            .fog, .fog, .fog,
            .none, .none, .none, .none, .none, .none, .none
        ]
        let model = makeModel(forecast: forecast(fogConditions: fogConditions))

        await model.loadIfNeeded()

        #expect(model.state.result?.periods.map(\.recommendation.title) == ["Don’t wear", "Wear"])
        #expect(model.state.result?.periods.first?.recommendation.reason == "Fog is expected.")
    }

    @Test func repeatedLoadDoesNotDuplicateProviderRequests() async {
        let locationProvider = CountingLocationProvider(reading: locationReading())
        let weatherProvider = CountingWeatherProvider(forecast: forecast())
        let store = MemoryCacheDataStore()
        let model = RecommendationViewModel(
            locationProvider: locationProvider,
            weatherProvider: weatherProvider,
            locationCache: LocationCache(store: store),
            weatherCache: WeatherCache(store: store),
            now: { self.now }
        )

        await model.loadIfNeeded()
        await model.loadIfNeeded()

        #expect(locationProvider.requestCount == 1)
        #expect(await weatherProvider.requestCount == 1)
    }

    @Test func reusesRecentLocationWithoutRequestingAnotherFix() async {
        let store = MemoryCacheDataStore()
        let locationCache = LocationCache(store: store)
        await locationCache.save(locationReading())
        let locationProvider = CountingLocationProvider(reading: locationReading())
        let model = RecommendationViewModel(
            locationProvider: locationProvider,
            weatherProvider: FixedWeatherProvider(result: .success(forecast())),
            locationCache: locationCache,
            weatherCache: WeatherCache(store: store),
            now: { self.now }
        )

        await model.loadIfNeeded()

        #expect(locationProvider.requestCount == 0)
        #expect(model.state.result != nil)
    }

    @Test func weatherYoungerThanFifteenMinutesIsUsedWithoutFetching() async {
        let store = MemoryCacheDataStore()
        await LocationCache(store: store).save(locationReading())
        await WeatherCache(store: store).save(forecast(
            fetchedAt: now.addingTimeInterval(-(15 * 60 - 0.001))
        ))
        let provider = CountingWeatherProvider(forecast: forecast(temperature: 24))
        let model = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: provider,
            locationCache: LocationCache(store: store),
            weatherCache: WeatherCache(store: store),
            now: { self.now }
        )

        await model.loadIfNeeded()

        #expect(await provider.requestCount == 0)
        #expect(model.state.result?.isUsingSavedWeather == true)
        #expect(model.state.result?.isRefreshing == false)
        #expect(model.state.result?.periods.first?.recommendation.title == "Wear")
    }

    @Test func weatherAtFifteenMinutesIsShownAndRefreshed() async throws {
        let store = MemoryCacheDataStore()
        await LocationCache(store: store).save(locationReading())
        await WeatherCache(store: store).save(forecast(
            fetchedAt: now.addingTimeInterval(-15 * 60)
        ))
        let provider = PendingWeatherProvider()
        let model = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: provider,
            locationCache: LocationCache(store: store),
            weatherCache: WeatherCache(store: store),
            now: { self.now }
        )

        let load = Task { await model.loadIfNeeded() }
        while await provider.requestCount == 0 { await Task.yield() }

        #expect(model.state.result?.isUsingSavedWeather == true)
        #expect(model.state.result?.isRefreshing == true)
        await provider.complete(with: .success(forecast(temperature: 24)))
        await load.value
        #expect(model.state.result?.isUsingSavedWeather == false)
    }

    @Test func weatherAtNinetyMinutesIsShownWhileOverNinetyIsNot() async {
        let boundaryClock = LockedTestClock(now)
        let boundaryStore = MemoryCacheDataStore()
        await LocationCache(store: boundaryStore).save(locationReading())
        await WeatherCache(store: boundaryStore).save(forecast(
            fetchedAt: now.addingTimeInterval(-90 * 60)
        ))
        let boundaryProvider = PendingWeatherProvider()
        let boundary = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: boundaryProvider,
            locationCache: LocationCache(store: boundaryStore),
            weatherCache: WeatherCache(store: boundaryStore),
            now: { boundaryClock.value }
        )

        let boundaryLoad = Task { await boundary.loadIfNeeded() }
        while await boundaryProvider.requestCount == 0 { await Task.yield() }
        #expect(boundary.state.result?.isRefreshing == true)
        await boundaryProvider.complete(with: .failure(.network))
        await boundaryLoad.value
        boundaryClock.advance(by: 0.001)
        await boundary.appBecameActive()
        #expect(boundary.state == .weatherDataExpired)
        #expect(await boundaryProvider.requestCount == 1)

        let expiredStore = MemoryCacheDataStore()
        await LocationCache(store: expiredStore).save(locationReading())
        await WeatherCache(store: expiredStore).save(forecast(
            fetchedAt: now.addingTimeInterval(-(90 * 60 + 0.001))
        ))
        let expiredProvider = PendingWeatherProvider()
        let expired = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: expiredProvider,
            locationCache: LocationCache(store: expiredStore),
            weatherCache: WeatherCache(store: expiredStore),
            now: { self.now }
        )

        let expiredLoad = Task { await expired.loadIfNeeded() }
        while await expiredProvider.requestCount == 0 { await Task.yield() }
        #expect(expired.state == .loading)
        await expiredProvider.complete(with: .failure(.network))
        await expiredLoad.value
        #expect(expired.state == .weatherDataExpired)
    }

    @Test func pullToRefreshIsBlockedUntilFifteenMinutesAndWhileRunning() async {
        let clock = LockedTestClock(now)
        let store = MemoryCacheDataStore()
        await LocationCache(store: store).save(locationReading())
        await WeatherCache(store: store).save(forecast(
            fetchedAt: now.addingTimeInterval(-10 * 60)
        ))
        let provider = PendingWeatherProvider()
        let model = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: provider,
            locationCache: LocationCache(store: store),
            weatherCache: WeatherCache(store: store),
            now: { clock.value }
        )
        await model.loadIfNeeded()

        await model.manualRefresh()
        #expect(await provider.requestCount == 0)

        clock.advance(by: 5 * 60)
        let refresh = Task { await model.manualRefresh() }
        while await provider.requestCount == 0 { await Task.yield() }
        await model.manualRefresh()
        #expect(await provider.requestCount == 1)
        #expect(model.state.result?.isRefreshing == true)

        await provider.complete(with: .success(forecast(fetchedAt: clock.value)))
        await refresh.value
        #expect(model.state.result?.isRefreshing == false)
    }

    @Test func foregroundActivationRefreshesWeatherAtFifteenMinutes() async {
        let clock = LockedTestClock(now)
        let store = MemoryCacheDataStore()
        await LocationCache(store: store).save(locationReading())
        await WeatherCache(store: store).save(forecast(
            fetchedAt: now.addingTimeInterval(-10 * 60)
        ))
        let provider = CountingWeatherProvider(forecast: forecast())
        let model = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: provider,
            locationCache: LocationCache(store: store),
            weatherCache: WeatherCache(store: store),
            now: { clock.value }
        )
        await model.loadIfNeeded()
        #expect(await provider.requestCount == 0)

        clock.advance(by: 5 * 60)
        await model.appBecameActive()

        #expect(await provider.requestCount == 1)
    }

    @Test func failedManualRefreshAppliesThirtySecondCooldown() async {
        let clock = LockedTestClock(now)
        let store = MemoryCacheDataStore()
        await LocationCache(store: store).save(locationReading())
        await WeatherCache(store: store).save(forecast(
            fetchedAt: now.addingTimeInterval(-10 * 60)
        ))
        let provider = CountingResultWeatherProvider(result: .failure(.network))
        let model = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: provider,
            locationCache: LocationCache(store: store),
            weatherCache: WeatherCache(store: store),
            now: { clock.value }
        )
        await model.loadIfNeeded()
        clock.advance(by: 5 * 60)

        await model.manualRefresh()
        #expect(await provider.requestCount == 1)
        #expect(model.state.result?.refreshFailed == true)
        await model.manualRefresh()
        #expect(await provider.requestCount == 1)

        clock.advance(by: 31)
        await model.manualRefresh()
        #expect(await provider.requestCount == 2)
    }

    @Test func retryFailureAppliesThirtySecondCooldown() async {
        let clock = LockedTestClock(now)
        let store = MemoryCacheDataStore()
        let provider = CountingResultWeatherProvider(result: .failure(.network))
        let model = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: provider,
            locationCache: LocationCache(store: store),
            weatherCache: WeatherCache(store: store),
            now: { clock.value }
        )

        await model.loadIfNeeded()
        #expect(await provider.requestCount == 1)
        #expect(model.canRetry(at: clock.value))
        await model.retry()
        #expect(await provider.requestCount == 2)
        #expect(!model.canRetry(at: clock.value))
        await model.retry()
        #expect(await provider.requestCount == 2)

        clock.advance(by: 31)
        await model.retry()
        #expect(await provider.requestCount == 3)
    }

    @Test func presentsConciseResolvedLocality() async {
        let model = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: FixedWeatherProvider(result: .success(forecast())),
            locationCache: LocationCache(store: MemoryCacheDataStore()),
            weatherCache: WeatherCache(store: MemoryCacheDataStore()),
            localityResolver: FixedLocalityResolver(value: "Wenduine"),
            now: { self.now }
        )

        await model.loadIfNeeded()
        while model.locality == nil { await Task.yield() }

        #expect(model.locality == "Wenduine")
    }

    @Test func displaysCachedResultImmediatelyThenReplacesItWithLiveData() async throws {
        let store = MemoryCacheDataStore()
        let locationCache = LocationCache(store: store)
        let weatherCache = WeatherCache(store: store)
        await locationCache.save(locationReading())
        await weatherCache.save(forecast(fetchedAt: now.addingTimeInterval(-20 * 60)))
        let provider = PendingWeatherProvider()
        let model = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: provider,
            locationCache: locationCache,
            weatherCache: weatherCache,
            now: { self.now }
        )

        let load = Task { await model.loadIfNeeded() }
        while await provider.requestCount == 0 { await Task.yield() }

        #expect(model.state.result?.weatherFetchedAt == now.addingTimeInterval(-20 * 60))
        #expect(model.state.result?.isUsingSavedWeather == true)
        #expect(model.state.result?.isRefreshing == true)
        #expect(model.state.result?.periods.first?.recommendation.title == "Wear")

        await provider.complete(with: .success(forecast(temperature: 24)))
        await load.value
        #expect(model.state.result?.isUsingSavedWeather == false)
        #expect(model.state.result?.isRefreshing == false)
        #expect(model.state.result?.periods.first?.recommendation.title == "Don’t wear")
    }

    @Test func keepsStillValidCacheVisibleWhenRefreshFails() async throws {
        let store = MemoryCacheDataStore()
        let locationCache = LocationCache(store: store)
        let weatherCache = WeatherCache(store: store)
        await locationCache.save(locationReading())
        await weatherCache.save(forecast(fetchedAt: now.addingTimeInterval(-20 * 60)))
        let model = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: FixedWeatherProvider(result: .failure(.network)),
            locationCache: locationCache,
            weatherCache: weatherCache,
            now: { self.now }
        )

        await model.loadIfNeeded()

        #expect(model.state.result?.weatherFetchedAt == now.addingTimeInterval(-20 * 60))
        #expect(model.state.result?.isUsingSavedWeather == true)
        #expect(model.state.result?.refreshFailed == true)
        #expect(model.state.result?.isRefreshing == false)
        #expect(model.state.result?.periods.first?.recommendation.title == "Wear")
    }

    @Test func staleWeatherNeverProducesFallbackResult() async {
        let store = MemoryCacheDataStore()
        let locationCache = LocationCache(store: store)
        let weatherCache = WeatherCache(store: store)
        await locationCache.save(locationReading())
        await weatherCache.save(forecast(fetchedAt: now.addingTimeInterval(-(90 * 60 + 0.001))))
        let model = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: FixedWeatherProvider(result: .failure(.network)),
            locationCache: locationCache,
            weatherCache: weatherCache,
            now: { self.now }
        )

        await model.loadIfNeeded()

        #expect(model.state == .weatherDataExpired)
    }

    @Test func weatherRequestTimeoutProducesExplicitFailure() async {
        let store = MemoryCacheDataStore()
        let model = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: SlowWeatherProvider(),
            locationCache: LocationCache(store: store),
            weatherCache: WeatherCache(store: store),
            now: { self.now },
            sleep: { _ in }
        )

        await model.loadIfNeeded()

        #expect(model.state == .weatherUnavailable)
    }

    private func makeModel(forecast: NormalizedForecast) -> RecommendationViewModel {
        let store = MemoryCacheDataStore()
        return RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: FixedWeatherProvider(result: .success(forecast)),
            locationCache: LocationCache(store: store),
            weatherCache: WeatherCache(store: store),
            now: { self.now }
        )
    }

    private func fixedLocationProvider() -> FixedLocationProvider {
        FixedLocationProvider(result: .success(locationReading()))
    }

    private func locationReading() -> LocationReading {
        LocationReading(identity: location, accuracyMeters: 25, timestamp: now)
    }

    private func forecast(
        fetchedAt: Date? = nil,
        amount: Double = 0,
        amounts: [Double]? = nil,
        chance: Double = 0,
        temperature: Double = 12,
        fogOrMist: FogOrMistCondition? = nil,
        fogConditions: [FogOrMistCondition]? = nil
    ) -> NormalizedForecast {
        let hours = (0..<10).map { offset in
            HourlyWeather(
                timestamp: currentHour.addingTimeInterval(TimeInterval(offset * 3_600)),
                timezoneIdentifier: "Europe/Brussels",
                actualTemperatureCelsius: temperature,
                apparentTemperatureCelsius: temperature,
                precipitationAmountMillimeters: amounts?[safe: offset] ?? amount,
                precipitationType: (amounts?[safe: offset] ?? amount) > 0
                    ? PrecipitationType.rain
                    : PrecipitationType.none,
                precipitationChanceFraction: chance,
                fogOrMistCondition: fogConditions?[safe: offset] ?? fogOrMist
            )
        }
        return NormalizedForecast(
            hours: hours,
            metadata: ForecastMetadata(fetchedAt: fetchedAt ?? now, location: location)
        )
    }
}

@MainActor
private final class CountingLocationProvider: LocationProvider {
    let reading: LocationReading
    private(set) var requestCount = 0

    init(reading: LocationReading) {
        self.reading = reading
    }

    func currentLocation() async throws -> LocationReading {
        requestCount += 1
        return reading
    }
}

private actor CountingWeatherProvider: WeatherProvider {
    let forecast: NormalizedForecast
    private(set) var requestCount = 0

    init(forecast: NormalizedForecast) {
        self.forecast = forecast
    }

    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        requestCount += 1
        return forecast
    }
}

private actor CountingResultWeatherProvider: WeatherProvider {
    let result: Result<NormalizedForecast, WeatherProviderError>
    private(set) var requestCount = 0

    init(result: Result<NormalizedForecast, WeatherProviderError>) {
        self.result = result
    }

    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        requestCount += 1
        return try result.get()
    }
}

private actor PendingWeatherProvider: WeatherProvider {
    private(set) var requestCount = 0
    private var continuation: CheckedContinuation<NormalizedForecast, any Error>?

    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        requestCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func complete(with result: Result<NormalizedForecast, WeatherProviderError>) {
        continuation?.resume(with: result.mapError { $0 as any Error })
        continuation = nil
    }
}

private struct SlowWeatherProvider: WeatherProvider {
    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        try await Task.sleep(for: .seconds(60))
        throw WeatherProviderError.unavailable
    }
}

@MainActor
private struct FixedLocalityResolver: LocalityResolving {
    let value: String?

    func locality(for location: LocationIdentity) async -> String? {
        value
    }
}

private final class LockedTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date

    init(_ date: Date) {
        self.date = date
    }

    var value: Date {
        lock.withLock { date }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { date = date.addingTimeInterval(interval) }
    }
}

private extension RecommendationViewModel.State {
    var result: DailyRecommendationPresentation? {
        guard case .result(let presentation) = self else { return nil }
        return presentation
    }
}

private extension NormalizedForecast {
    func replacingHours(with hours: [HourlyWeather]) -> NormalizedForecast {
        NormalizedForecast(hours: hours, metadata: metadata)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
