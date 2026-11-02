import Foundation
import Testing
@testable import Can_I_Wear

@MainActor
struct RecommendationRefreshTests {
    private let start = ItemEngineFixtures.dayEnd.addingTimeInterval(-18 * 3_600)

    @Test func automaticFailureIsAttemptedOnceAtRefreshAndOnceAtExpiry() async throws {
        let forecast = fixture()
        let clock = RefreshTestClock(start)
        let weather = RefreshTestWeatherProvider(result: .failure(.network))
        let model = await makeModel(forecast: forecast, clock: clock, weather: weather)
        await model.loadIfNeeded()
        #expect(result(model)?.isUsingSavedWeather == true)

        clock.advance(15 * 60)
        await model.appBecameActive()
        #expect(await weather.requestCount == 1)
        #expect(result(model)?.refreshFailed == true)
        clock.advance(31)
        await model.appBecameActive()
        #expect(await weather.requestCount == 1)

        clock.advance(75 * 60 - 31)
        await model.appBecameActive()
        #expect(await weather.requestCount == 2)
        #expect(result(model) != nil, "Exactly 90 minutes remains usable")
        clock.advance(0.001)
        await model.appBecameActive()
        #expect(model.state == .weatherDataExpired)
        #expect(await weather.requestCount == 2)
    }

    @Test func failedRequestCannotRestoreFallbackThatExpiresWhileFetching() async throws {
        let forecast = fixture()
        let clock = RefreshTestClock(start.addingTimeInterval(89 * 60))
        let weather = RefreshTestWeatherProvider(result: .failure(.network), beforeResult: {
            clock.advance(61)
        })
        let model = await makeModel(forecast: forecast, clock: clock, weather: weather)
        await model.loadIfNeeded()
        #expect(model.state == .weatherUnavailable)
        #expect(result(model) == nil)
        #expect(await weather.requestCount == 1)
    }

    @Test func selectionChangedDuringWeatherRequestUsesCurrentSelection() async throws {
        let forecast = fixture()
        let clock = RefreshTestClock(start)
        let weather = RefreshTestWeatherProvider(result: .success(forecast))
        let model = await makeModel(forecast: forecast, clock: clock, weather: weather)
        await model.loadIfNeeded()
        await weather.setBeforeResult { model.updateSelectedItems([.sunglasses]) }
        clock.advance(15 * 60)
        await model.manualRefresh()
        #expect(result(model)?.itemResults.map(\.item) == [.sunglasses])
        #expect(result(model)?.itemResults.first?.evaluation?.verdict == .useful)
        #expect(await weather.requestCount == 1)
    }

    @Test func timerReevaluatesAtHourBoundaryWithoutAnEarlyWeatherRequest() async throws {
        let fetchedAt = start.addingTimeInterval(59 * 60)
        let forecast = fixture(fetchedAt: fetchedAt, usefulHours: 2)
        let clock = RefreshTestClock(fetchedAt)
        let sleeper = RefreshTestSleeper()
        let weather = RefreshTestWeatherProvider(result: .failure(.network))
        let model = await makeModel(
            forecast: forecast, clock: clock, weather: weather, automaticRefreshSleep: { try await sleeper.sleep($0) }
        )
        model.updateSelectedItems([.sunglasses])
        await model.loadIfNeeded()
        #expect(result(model)?.itemResults.first?.evaluation?.verdict == .useful)
        let monitor = Task { await model.monitorAutomaticRefreshes() }
        defer { monitor.cancel() }
        try await sleeper.waitForSleeps(1)
        #expect(await sleeper.durations == [.seconds(60)])
        clock.advance(60)
        await sleeper.wake()
        try await sleeper.waitForSleeps(2)
        #expect(result(model)?.itemResults.first?.evaluation?.verdict == .brieflyUseful)
        #expect(result(model)?.evaluationHour == start.addingTimeInterval(3_600))
        #expect(await weather.requestCount == 0)
        monitor.cancel()
        await monitor.value
        #expect(await sleeper.pendingCount == 0)
    }

    @Test func timerRunsRoutineRefreshExpiryAttemptAndRemovesExpiredAdvice() async throws {
        let clock = RefreshTestClock(start)
        let sleeper = RefreshTestSleeper()
        let weather = RefreshTestWeatherProvider(result: .failure(.network))
        let model = await makeModel(
            forecast: fixture(), clock: clock, weather: weather, automaticRefreshSleep: { try await sleeper.sleep($0) }
        )
        await model.loadIfNeeded()
        let monitor = Task { await model.monitorAutomaticRefreshes() }
        defer { monitor.cancel() }
        for (count, delay) in [(1, 900.0), (2, 2_700), (3, 1_800), (4, 0.001)] {
            try await sleeper.waitForSleeps(count)
            let duration = try #require(await sleeper.durations.last)
            let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
            #expect(abs(seconds - delay) < 0.000_001)
            clock.advance(delay)
            await sleeper.wake()
        }
        await monitor.value
        #expect(model.state == .weatherDataExpired)
        #expect(await weather.requestCount == 2)
        #expect(await sleeper.pendingCount == 0)
    }

    @Test func cancellingTimerDoesNotRefreshAndIdleStateDoesNotScheduleWork() async throws {
        let clock = RefreshTestClock(start)
        let sleeper = RefreshTestSleeper()
        let weather = RefreshTestWeatherProvider(result: .failure(.network))
        let model = await makeModel(
            forecast: fixture(), clock: clock, weather: weather, automaticRefreshSleep: { try await sleeper.sleep($0) }
        )
        await model.monitorAutomaticRefreshes()
        #expect(await sleeper.durations.isEmpty)
        await model.loadIfNeeded()
        let monitor = Task { await model.monitorAutomaticRefreshes() }
        defer { monitor.cancel() }
        try await sleeper.waitForSleeps(1)
        monitor.cancel()
        await monitor.value
        #expect(await weather.requestCount == 0)
        #expect(await sleeper.pendingCount == 0)
        #expect(result(model) != nil)
    }

    private func fixture(fetchedAt: Date? = nil, usefulHours: Int = 18) -> NormalizedForecast {
        NormalizedForecast(
            hours: (0..<18).map {
                ItemEngineFixtures.hour(at: start.addingTimeInterval(Double($0) * 3_600), sky: $0 < usefulHours ? .clear : .overcast)
            },
            metadata: ForecastMetadata(fetchedAt: fetchedAt ?? start, location: LocationIdentity(latitude: 50.85, longitude: 4.35))
        )
    }

    private func makeModel(
        forecast: NormalizedForecast, clock: RefreshTestClock, weather: any WeatherProvider,
        automaticRefreshSleep: @escaping RecommendationViewModel.Sleep = { try await Task.sleep(for: $0) }
    ) async -> RecommendationViewModel {
        let store = MemoryCacheDataStore()
        let reading = LocationReading(identity: forecast.metadata.location, accuracyMeters: 10, timestamp: clock.value)
        await LocationCache(store: store).save(reading)
        await WeatherCache(store: store).save(forecast)
        return RecommendationViewModel(
            locationProvider: FixedLocationProvider(result: .success(reading)), weatherProvider: weather,
            locationCache: LocationCache(store: store), weatherCache: WeatherCache(store: store),
            localityResolver: RefreshTestLocalityResolver(), now: { clock.value }, automaticRefreshSleep: automaticRefreshSleep
        )
    }

    private func result(_ model: RecommendationViewModel) -> DailyRecommendationPresentation? {
        guard case .result(let presentation) = model.state else { return nil }
        return presentation
    }
}

private final class RefreshTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date
    init(_ date: Date) { self.date = date }
    var value: Date { lock.withLock { date } }
    func advance(_ seconds: TimeInterval) { lock.withLock { date = date.addingTimeInterval(seconds) } }
}

private actor RefreshTestWeatherProvider: WeatherProvider {
    let result: Result<NormalizedForecast, WeatherProviderError>
    private var beforeResult: @MainActor @Sendable () -> Void
    private(set) var requestCount = 0

    init(
        result: Result<NormalizedForecast, WeatherProviderError>,
        beforeResult: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.result = result
        self.beforeResult = beforeResult
    }

    func setBeforeResult(_ action: @escaping @MainActor @Sendable () -> Void) { beforeResult = action }

    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        requestCount += 1
        await beforeResult()
        return try result.get()
    }
}

private actor RefreshTestSleeper {
    private(set) var durations: [Duration] = []
    private var pending: [UUID: CheckedContinuation<Void, any Error>] = [:]
    var pendingCount: Int { pending.count }

    func sleep(_ duration: Duration) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                pending[id] = continuation
                durations.append(duration)
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    func wake() {
        let continuations = Array(pending.values)
        pending.removeAll()
        for continuation in continuations { continuation.resume() }
    }

    func waitForSleeps(_ count: Int) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while ContinuousClock.now < deadline {
            if durations.count >= count { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        try #require(durations.count >= count, "The automatic timer did not reach its next sleep")
    }

    private func cancel(_ id: UUID) {
        pending.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }
}

@MainActor
private struct RefreshTestLocalityResolver: LocalityResolving {
    func locality(for location: LocationIdentity) async -> String? { "Test locality" }
}
