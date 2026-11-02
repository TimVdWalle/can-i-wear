import Foundation
import Testing
@testable import Can_I_Wear

@MainActor
struct ForecastLoaderTests {
    private let now = ItemEngineFixtures.dayEnd.addingTimeInterval(-3 * 3_600)
    private let location = LocationIdentity(latitude: 50.85, longitude: 4.35)

    @Test func locationReuseBypassAndAcquisitionPreserveCacheSemantics() async throws {
        let store = MemoryCacheDataStore()
        let reading = LocationReading(identity: location, accuracyMeters: 10, timestamp: now)
        let loader = makeLoader(store: store, locationResult: .success(reading))
        guard case .device(cacheRejection: .missing) = await loader.locationSource(reacquire: false, at: now) else {
            Issue.record("Missing saved location must require acquisition")
            return
        }
        #expect(try await loader.acquireLocation() == reading)
        guard case .cached(let saved, let age) = await loader.locationSource(reacquire: false, at: now) else {
            Issue.record("An accepted reading must be saved for reuse")
            return
        }
        #expect(saved == reading)
        #expect(age == 0)
        guard case .device(cacheRejection: nil) = await loader.locationSource(reacquire: true, at: now) else {
            Issue.record("Manual reacquisition must bypass valid saved location")
            return
        }
        guard case .device(cacheRejection: .stale) = await loader.locationSource(
            reacquire: false, at: now.addingTimeInterval(1_801)
        ) else {
            Issue.record("Stale location must require acquisition")
            return
        }
    }

    @Test(arguments: [LocationProviderError.permissionDenied, .unavailable, .timedOut, .cancelled])
    func locationErrorsPropagateWithoutSaving(_ error: LocationProviderError) async {
        let store = MemoryCacheDataStore()
        let loader = makeLoader(store: store, locationResult: .failure(error))
        await #expect(throws: error) { try await loader.acquireLocation() }
        #expect(await LocationCache(store: store).validReading(at: now) == nil)
    }

    @Test func weatherLookupPreservesAgeLocationAndRejectionDetails() async {
        let store = MemoryCacheDataStore()
        let loader = makeLoader(store: store)
        #expect(await loader.cachedWeather(for: location, at: now) == .unavailable(.missing))
        let forecast = fixture()
        await loader.saveAcceptedForecast(forecast)
        #expect(await loader.cachedWeather(for: location, at: now) == .valid(forecast, age: 0, distanceMeters: 0))
        #expect(await loader.cachedWeather(for: location, at: now.addingTimeInterval(5_400))
            == .valid(forecast, age: 5_400, distanceMeters: 0))
        guard case .expired = await loader.cachedWeather(for: location, at: now.addingTimeInterval(5_401)) else {
            Issue.record("Weather over the maximum usable age must be expired")
            return
        }
        let moved = LocationIdentity(latitude: 51.22, longitude: 4.40)
        #expect(loader.matchesForecastLocation(forecast, location: location))
        #expect(!loader.matchesForecastLocation(forecast, location: moved))
        guard case .unavailable(.locationMismatch) = await loader.cachedWeather(for: moved, at: now) else {
            Issue.record("Another location must not reuse this forecast")
            return
        }
    }

    @Test func liveCandidateIsNotSavedUntilCallerAcceptsItAndTimeoutIsCancelled() async throws {
        let store = MemoryCacheDataStore()
        let probe = LoaderSleepProbe()
        let forecast = fixture()
        let loader = makeLoader(store: store, weather: FixedWeatherProvider(result: .success(forecast)), sleep: probe.sleep)
        #expect(loader.weatherProviderName == "FixedWeatherProvider")
        #expect(loader.weatherRequestTimeout == .seconds(10))
        #expect(try await loader.fetchLiveForecast(for: location) == forecast)
        #expect(probe.duration == .seconds(10))
        #expect(probe.wasCancelled)
        #expect(await WeatherCache(store: store).validForecast(at: now, for: location) == nil)
        await loader.saveAcceptedForecast(forecast)
        #expect(await WeatherCache(store: store).validForecast(at: now, for: location) == forecast)
    }

    @Test func timeoutCancelsWeatherWorkAndNeverSavesCandidate() async {
        let store = MemoryCacheDataStore()
        let weather = LoaderCancellableWeatherProvider()
        let loader = makeLoader(store: store, weather: weather, sleep: { _ in })
        await #expect(throws: WeatherProviderError.timedOut) {
            try await loader.fetchLiveForecast(for: location)
        }
        #expect(await weather.wasCancelled)
        #expect(await WeatherCache(store: store).validForecast(at: now, for: location) == nil)
    }

    @Test func providerErrorsAreNotConvertedIntoSuccessfulCandidates() async {
        let loader = makeLoader(store: MemoryCacheDataStore(), weather: FixedWeatherProvider(result: .failure(.cancelled)))
        await #expect(throws: WeatherProviderError.cancelled) {
            try await loader.fetchLiveForecast(for: location)
        }
    }

    @Test func cancellingParentStopsBothWeatherWorkAndTimeout() async throws {
        let store = MemoryCacheDataStore()
        let weather = LoaderCancellableWeatherProvider()
        let probe = LoaderSleepProbe()
        let loader = makeLoader(store: store, weather: weather, sleep: probe.sleep)
        let request = Task { try await loader.fetchLiveForecast(for: location) }
        defer { request.cancel() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !(await weather.wasStarted), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        request.cancel()
        do {
            _ = try await request.value
            Issue.record("A cancelled load must not return a forecast")
        } catch {
            #expect(error is CancellationError)
        }
        #expect(await weather.wasStarted)
        #expect(await weather.wasCancelled)
        #expect(probe.wasCancelled)
        #expect(await WeatherCache(store: store).validForecast(at: now, for: location) == nil)
    }

    private func makeLoader(
        store: MemoryCacheDataStore,
        locationResult: Result<LocationReading, LocationProviderError> = .failure(.unavailable),
        weather: any WeatherProvider = FixedWeatherProvider(result: .failure(.unavailable)),
        sleep: @escaping ForecastLoader.Sleep = { try await Task.sleep(for: $0) }
    ) -> ForecastLoader {
        ForecastLoader(
            locationProvider: FixedLocationProvider(result: locationResult), weatherProvider: weather,
            locationCache: LocationCache(store: store), weatherCache: WeatherCache(store: store), sleep: sleep
        )
    }

    private func fixture() -> NormalizedForecast {
        NormalizedForecast(
            hours: (0..<3).map { ItemEngineFixtures.hour(at: now.addingTimeInterval(Double($0) * 3_600)) },
            metadata: ForecastMetadata(fetchedAt: now, location: location)
        )
    }
}

private final class LoaderSleepProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedDuration: Duration?
    private var cancelled = false
    var duration: Duration? { lock.withLock { recordedDuration } }
    var wasCancelled: Bool { lock.withLock { cancelled } }

    nonisolated func sleep(_ duration: Duration) async throws {
        lock.withLock { recordedDuration = duration }
        do {
            try await Task.sleep(for: .seconds(60))
        } catch {
            lock.withLock { cancelled = true }
            throw error
        }
    }
}

private actor LoaderCancellableWeatherProvider: WeatherProvider {
    private(set) var wasStarted = false
    private(set) var wasCancelled = false
    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        wasStarted = true
        do {
            try await Task.sleep(for: .seconds(60))
            throw WeatherProviderError.unavailable
        } catch {
            wasCancelled = Task.isCancelled
            throw error
        }
    }
}
