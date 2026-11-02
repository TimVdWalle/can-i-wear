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

        #expect(wear.state.result?.periods.first?.recommendation.title == "YES")
        #expect(caution.state.result?.periods.first?.recommendation.title == "MAYBE")
        #expect(avoid.state.result?.periods.first?.recommendation.title == "NO")
        #expect(avoid.state.result?.periods.first?.recommendation.reason.contains("damage leather") == true)
        #expect(fog.state.result?.periods.first?.recommendation.title == "NO")
        #expect(fog.state.result?.periods.first?.recommendation.reason == "Fog is expected.")
    }

    @Test func representsLocationAndWeatherFailuresExplicitly() async {
        let deniedStore = MemoryCacheDataStore()
        let denied = RecommendationViewModel(
            locationProvider: FixedLocationProvider(result: .failure(.permissionDenied)),
            weatherProvider: FixedWeatherProvider(result: .failure(.unavailable)),
            locationCache: LocationCache(store: deniedStore),
            weatherCache: WeatherCache(store: deniedStore),
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
            now: { self.now }
        )
        let weatherStore = MemoryCacheDataStore()
        let weatherFailure = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: FixedWeatherProvider(result: .failure(.network)),
            locationCache: LocationCache(store: weatherStore),
            weatherCache: WeatherCache(store: weatherStore),
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
            now: { self.now }
        )

        await denied.loadIfNeeded()
        await weatherFailure.loadIfNeeded()

        #expect(denied.state == .locationPermissionDenied)
        #expect(weatherFailure.state == .weatherUnavailable)
    }

    @Test func locationFailuresStopWeatherRequestsAndAllowRetry() async {
        let failures: [(LocationProviderError, RecommendationViewModel.State)] = [
            (.permissionDenied, .locationPermissionDenied),
            (.cancelled, .idle),
            (.unavailable, .locationUnavailable),
            (.timedOut, .locationUnavailable)
        ]

        for (error, expectedState) in failures {
            let store = MemoryCacheDataStore()
            let weatherProvider = CountingWeatherProvider(forecast: forecast())
            let model = RecommendationViewModel(
                locationProvider: FixedLocationProvider(result: .failure(error)),
                weatherProvider: weatherProvider,
                locationCache: LocationCache(store: store),
                weatherCache: WeatherCache(store: store),
                diagnostics: makeTestDiagnostics(),
                localityResolver: StubGeocodingResolver(),
                now: { self.now }
            )

            await model.loadIfNeeded()

            #expect(model.state == expectedState)
            #expect(await weatherProvider.requestCount == 0)
            #expect(model.retryAvailableAt == nil)

            await model.retry()

            #expect(model.state == expectedState)
            #expect(await weatherProvider.requestCount == 0)
            #expect(model.retryAvailableAt == now.addingTimeInterval(30))
        }
    }

    @Test func representsIncompleteForecastWithoutInventingAResult() async {
        let model = makeModel(forecast: forecast().replacingHours(with: []))

        await model.loadIfNeeded()

        #expect(model.state == .forecastIncomplete)
    }

    @Test func presentsMaterialWeatherChangesAsOrderedPeriods() async {
        let model = makeModel(forecast: forecast(amounts: [1, 1, 1, 0, 0, 0, 0, 0, 0, 0]))

        await model.loadIfNeeded()

        #expect(model.state.result?.periods.map(\.recommendation.title) == ["NO", "YES"])
        #expect(model.state.result?.periods[0].interval.end == model.state.result?.periods[1].interval.start)
    }

    @Test func presentsExplicitFogAsAnAvoidPeriod() async {
        let fogConditions: [FogOrMistCondition] = [
            .fog, .fog, .fog,
            .none, .none, .none, .none, .none, .none, .none
        ]
        let model = makeModel(forecast: forecast(fogConditions: fogConditions))

        await model.loadIfNeeded()

        #expect(model.state.result?.periods.map(\.recommendation.title) == ["NO", "YES"])
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
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
            now: { self.now }
        )

        await model.loadIfNeeded()
        await model.loadIfNeeded()

        #expect(locationProvider.requestCount == 1)
        #expect(await weatherProvider.requestCount == 1)
        #expect(model.state.result?.hours.count == 10)
        #expect(model.state.result?.hours.first?.id == currentHour)
        #expect(model.state.result?.summary?.title == "YES")
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
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
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
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
            now: { self.now }
        )

        await model.loadIfNeeded()

        #expect(await provider.requestCount == 0)
        #expect(model.state.result?.isUsingSavedWeather == true)
        #expect(model.state.result?.isRefreshing == false)
        #expect(model.state.result?.periods.first?.recommendation.title == "YES")
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
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
            now: { self.now }
        )

        let load = Task { await model.loadIfNeeded() }
        defer { load.cancel() }
        try await waitUntil("the weather request to start") { await provider.requestCount > 0 }

        #expect(model.state.result?.isUsingSavedWeather == true)
        #expect(model.state.result?.isRefreshing == true)
        await provider.complete(with: .success(forecast(temperature: 24)))
        await load.value
        #expect(model.state.result?.isUsingSavedWeather == false)
    }

    @Test func weatherAtNinetyMinutesIsShownWhileOverNinetyIsNot() async throws {
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
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
            now: { boundaryClock.value }
        )

        let boundaryLoad = Task { await boundary.loadIfNeeded() }
        defer { boundaryLoad.cancel() }
        try await waitUntil("the boundary weather request to start") { await boundaryProvider.requestCount > 0 }
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
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
            now: { self.now }
        )

        let expiredLoad = Task { await expired.loadIfNeeded() }
        defer { expiredLoad.cancel() }
        try await waitUntil("the expired weather request to start") { await expiredProvider.requestCount > 0 }
        #expect(expired.state == .loading)
        await expiredProvider.complete(with: .failure(.network))
        await expiredLoad.value
        #expect(expired.state == .weatherDataExpired)
    }

    @Test func pullToRefreshReacquiresLocationButMatchingWeatherWaitsFifteenMinutes() async throws {
        let clock = LockedTestClock(now)
        let store = MemoryCacheDataStore()
        await LocationCache(store: store).save(locationReading())
        await WeatherCache(store: store).save(forecast(
            fetchedAt: now.addingTimeInterval(-10 * 60)
        ))
        let provider = PendingWeatherProvider()
        let nearby = LocationReading(
            identity: LocationIdentity(latitude: 50.86, longitude: 4.35), accuracyMeters: 25, timestamp: now
        )
        let locationProvider = CountingLocationProvider(reading: nearby)
        let model = RecommendationViewModel(
            locationProvider: locationProvider,
            weatherProvider: provider,
            locationCache: LocationCache(store: store),
            weatherCache: WeatherCache(store: store),
            diagnostics: makeTestDiagnostics(),
            localityResolver: FixedLocalityResolver(value: "Brussels"),
            now: { clock.value }
        )
        await model.loadIfNeeded()

        let savedHours = model.state.result?.hours
        await model.manualRefresh()
        #expect(await provider.requestCount == 0)
        #expect(locationProvider.requestCount == 1)
        #expect(model.state.result?.isRefreshing == false)
        #expect(await LocationCache(store: store).validReading(at: now) == nearby)

        clock.advance(by: 5 * 60)
        let refresh = Task { await model.manualRefresh() }
        defer { refresh.cancel() }
        try await waitUntil("the manual weather request to start") { await provider.requestCount > 0 }
        await model.manualRefresh()
        #expect(await provider.requestCount == 1)
        #expect(locationProvider.requestCount == 2)
        #expect(model.state.result?.isRefreshing == true)
        #expect(model.state.result?.hours == savedHours)
        #expect(model.state.result?.summary?.level == .okay)

        await provider.complete(with: .success(forecast(fetchedAt: clock.value)))
        await refresh.value
        #expect(model.state.result?.isRefreshing == false)
        #expect(model.state.result?.hours == savedHours)
    }

    @Test func pullToRefreshWithoutDisplayedForecastAcquiresLocationAndWeather() async {
        let store = MemoryCacheDataStore()
        let locationProvider = CountingLocationProvider(reading: locationReading())
        let weatherProvider = CountingWeatherProvider(forecast: forecast())
        let model = RecommendationViewModel(
            locationProvider: locationProvider, weatherProvider: weatherProvider,
            locationCache: LocationCache(store: store), weatherCache: WeatherCache(store: store),
            diagnostics: makeTestDiagnostics(),
            localityResolver: FixedLocalityResolver(value: "Brussels"), now: { self.now },
            initialState: .locationUnavailable
        )

        await model.manualRefresh()

        #expect(locationProvider.requestCount == 1)
        #expect(await weatherProvider.requestedLocations == [location])
        #expect(model.state.result?.summary?.level == .okay)
    }

    @Test func pullToRefreshFetchesForMovedLocationEvenWithFreshWeather() async {
        let store = MemoryCacheDataStore()
        let locationCache = LocationCache(store: store)
        await locationCache.save(locationReading())
        await WeatherCache(store: store).save(forecast())
        let moved = LocationIdentity(latitude: 51.22, longitude: 4.40)
        let reading = LocationReading(identity: moved, accuracyMeters: 25, timestamp: now)
        let locationProvider = CountingLocationProvider(reading: reading)
        let provider = CountingWeatherProvider(forecast: forecast(location: moved, temperature: 24))
        let model = RecommendationViewModel(
            locationProvider: locationProvider, weatherProvider: provider,
            locationCache: locationCache, weatherCache: WeatherCache(store: store),
            diagnostics: makeTestDiagnostics(),
            localityResolver: FixedLocalityResolver(value: "Antwerp"), now: { self.now }
        )
        await model.loadIfNeeded()
        #expect(locationProvider.requestCount == 0)
        #expect(await provider.requestCount == 0)

        await model.manualRefresh()

        #expect(locationProvider.requestCount == 1)
        #expect(await provider.requestedLocations == [moved])
        #expect(await locationCache.validReading(at: now) == reading)
        #expect(model.state.result?.summary?.level == .avoid)
        #expect(model.state.result?.isRefreshing == false)
        #expect(await WeatherCache(store: store).validForecast(at: now, for: moved)?.metadata.location == moved)
    }

    @Test func movedLocationFailureDoesNotRetainOrResurrectOldAdvice() async {
        let store = MemoryCacheDataStore()
        await LocationCache(store: store).save(locationReading())
        await WeatherCache(store: store).save(forecast())
        let moved = LocationIdentity(latitude: 51.22, longitude: 4.40)
        let provider = CountingResultWeatherProvider(result: .failure(.network))
        let model = RecommendationViewModel(
            locationProvider: CountingLocationProvider(reading: LocationReading(
                identity: moved, accuracyMeters: 25, timestamp: now
            )),
            weatherProvider: provider,
            locationCache: LocationCache(store: store), weatherCache: WeatherCache(store: store),
            diagnostics: makeTestDiagnostics(),
            localityResolver: FixedLocalityResolver(value: "Antwerp"), now: { self.now }
        )
        await model.loadIfNeeded()
        #expect(model.state.result?.summary?.level == .okay)

        await model.manualRefresh()

        #expect(await provider.requestCount == 1)
        #expect(model.state == .weatherUnavailable)
        #expect(model.retryAvailableAt == now.addingTimeInterval(30))
        await model.retry()
        #expect(await provider.requestCount == 1)
        model.updateSelectedItems([.sweater])
        await model.appBecameActive()
        #expect(model.state.result == nil)
    }

    @Test func pullToRefreshDoesNotOverlapLocationAcquisition() async throws {
        let store = MemoryCacheDataStore()
        await LocationCache(store: store).save(locationReading())
        await WeatherCache(store: store).save(forecast())
        let locationProvider = PendingLocationProvider()
        let weatherProvider = CountingWeatherProvider(forecast: forecast())
        let model = RecommendationViewModel(
            locationProvider: locationProvider, weatherProvider: weatherProvider,
            locationCache: LocationCache(store: store), weatherCache: WeatherCache(store: store),
            diagnostics: makeTestDiagnostics(),
            localityResolver: FixedLocalityResolver(value: "Brussels"), now: { self.now }
        )
        await model.loadIfNeeded()
        let refresh = Task { await model.manualRefresh() }
        defer { refresh.cancel() }
        try await waitUntil("the manual location request to start") { locationProvider.requestCount > 0 }
        let requestCount = locationProvider.requestCount
        await model.manualRefresh()
        await model.appBecameActive()
        locationProvider.complete(with: locationReading())
        await refresh.value

        #expect(requestCount == 1)
        #expect(locationProvider.requestCount == 1)
        #expect(await weatherProvider.requestCount == 0)
        #expect(model.state.result?.isRefreshing == false)
    }

    @Test func failedLocationRefreshKeepsValidAdviceAndAppliesCooldown() async {
        let clock = LockedTestClock(now)
        let store = MemoryCacheDataStore()
        await LocationCache(store: store).save(locationReading())
        await WeatherCache(store: store).save(forecast())
        let locationProvider = CountingResultLocationProvider(result: .failure(.timedOut))
        let provider = CountingWeatherProvider(forecast: forecast())
        let model = RecommendationViewModel(
            locationProvider: locationProvider, weatherProvider: provider,
            locationCache: LocationCache(store: store), weatherCache: WeatherCache(store: store),
            diagnostics: makeTestDiagnostics(),
            localityResolver: FixedLocalityResolver(value: "Brussels"), now: { clock.value }
        )
        await model.loadIfNeeded()
        await model.manualRefresh()

        #expect(locationProvider.requestCount == 1)
        #expect(await provider.requestCount == 0)
        #expect(model.state.result?.summary?.level == .okay)
        #expect(model.state.result?.refreshFailed == true)
        #expect(model.state.result?.isRefreshing == false)
        await model.manualRefresh()
        #expect(locationProvider.requestCount == 1)
        clock.advance(by: 30)
        await model.manualRefresh()
        #expect(locationProvider.requestCount == 2)
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
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
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
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
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
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
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

    @Test func presentsConciseResolvedLocality() async throws {
        let model = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: FixedWeatherProvider(result: .success(forecast())),
            locationCache: LocationCache(store: MemoryCacheDataStore()),
            weatherCache: WeatherCache(store: MemoryCacheDataStore()),
            diagnostics: makeTestDiagnostics(),
            localityResolver: FixedLocalityResolver(value: "Wenduine"),
            now: { self.now }
        )

        await model.loadIfNeeded()
        try await waitUntil("the concise locality lookup") { model.locality == "Wenduine" }

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
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
            now: { self.now }
        )

        let load = Task { await model.loadIfNeeded() }
        defer { load.cancel() }
        try await waitUntil("the live replacement request to start") { await provider.requestCount > 0 }

        #expect(model.state.result?.weatherFetchedAt == now.addingTimeInterval(-20 * 60))
        #expect(model.state.result?.isUsingSavedWeather == true)
        #expect(model.state.result?.isRefreshing == true)
        #expect(model.state.result?.periods.first?.recommendation.title == "YES")

        await provider.complete(with: .success(forecast(temperature: 24)))
        await load.value
        #expect(model.state.result?.isUsingSavedWeather == false)
        #expect(model.state.result?.isRefreshing == false)
        #expect(model.state.result?.periods.first?.recommendation.title == "NO")
        #expect(model.state.result?.hours.allSatisfy { $0.recommendation.level == .avoid } == true)
        #expect(model.state.result?.summary?.level == .avoid)
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
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
            now: { self.now }
        )

        await model.loadIfNeeded()

        #expect(model.state.result?.weatherFetchedAt == now.addingTimeInterval(-20 * 60))
        #expect(model.state.result?.isUsingSavedWeather == true)
        #expect(model.state.result?.refreshFailed == true)
        #expect(model.state.result?.isRefreshing == false)
        #expect(model.state.result?.periods.first?.recommendation.title == "YES")
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
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
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
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
            now: { self.now },
            sleep: { _ in }
        )

        await model.loadIfNeeded()

        #expect(model.state == .weatherUnavailable)
    }

    @Test(arguments: [false, true])
    func pendingWeatherProviderReleasesItsContinuationWhenCancelled(beforeRegistration: Bool) async throws {
        let provider = PendingWeatherProvider()
        let request = Task { try await provider.hourlyForecast(for: location) }
        defer { request.cancel() }
        if !beforeRegistration {
            try await waitUntil("the pending weather continuation") { await provider.hasPendingRequest }
        }
        request.cancel()
        await #expect(throws: WeatherProviderError.cancelled) { try await request.value }
        #expect(await !provider.hasPendingRequest)
    }

    @Test(arguments: [false, true])
    func pendingLocationProviderReleasesItsContinuationWhenCancelled(beforeRegistration: Bool) async throws {
        let provider = PendingLocationProvider()
        let request = Task { try await provider.currentLocation() }
        defer { request.cancel() }
        if !beforeRegistration {
            try await waitUntil("the pending location continuation") { provider.hasPendingRequest }
        }
        request.cancel()
        await #expect(throws: LocationProviderError.cancelled) { try await request.value }
        #expect(!provider.hasPendingRequest)
    }

    private func makeModel(forecast: NormalizedForecast) -> RecommendationViewModel {
        let store = MemoryCacheDataStore()
        return RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: FixedWeatherProvider(result: .success(forecast)),
            locationCache: LocationCache(store: store),
            weatherCache: WeatherCache(store: store),
            diagnostics: makeTestDiagnostics(),
            localityResolver: StubGeocodingResolver(),
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
        location forecastLocation: LocationIdentity? = nil,
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
            metadata: ForecastMetadata(fetchedAt: fetchedAt ?? now, location: forecastLocation ?? location)
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
    private(set) var requestedLocations: [LocationIdentity] = []

    init(forecast: NormalizedForecast) {
        self.forecast = forecast
    }

    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        requestCount += 1
        requestedLocations.append(location)
        return forecast
    }
}

@MainActor
private final class PendingLocationProvider: LocationProvider {
    private(set) var requestCount = 0
    private var continuation: CheckedContinuation<LocationReading, any Error>?
    private var completedReading: LocationReading?
    var hasPendingRequest: Bool { continuation != nil }

    func currentLocation() async throws -> LocationReading {
        requestCount += 1
        if let completedReading { return completedReading }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: LocationProviderError.cancelled)
                    return
                }
                self.continuation = continuation
            }
        } onCancel: {
            Task { @MainActor in self.cancel() }
        }
    }

    func complete(with reading: LocationReading) {
        completedReading = reading
        continuation?.resume(returning: reading)
        continuation = nil
    }

    private func cancel() {
        continuation?.resume(throwing: LocationProviderError.cancelled)
        continuation = nil
    }
}

@MainActor
private final class CountingResultLocationProvider: LocationProvider {
    let result: Result<LocationReading, LocationProviderError>
    private(set) var requestCount = 0

    init(result: Result<LocationReading, LocationProviderError>) {
        self.result = result
    }

    func currentLocation() async throws -> LocationReading {
        requestCount += 1
        return try result.get()
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
    var hasPendingRequest: Bool { continuation != nil }

    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        requestCount += 1
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: WeatherProviderError.cancelled)
                    return
                }
                self.continuation = continuation
            }
        } onCancel: {
            Task { await self.cancel() }
        }
    }

    func complete(with result: Result<NormalizedForecast, WeatherProviderError>) {
        continuation?.resume(with: result.mapError { $0 as any Error })
        continuation = nil
    }

    private func cancel() {
        continuation?.resume(throwing: WeatherProviderError.cancelled)
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
