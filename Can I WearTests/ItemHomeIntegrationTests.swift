import Foundation
import Testing
@testable import Can_I_Wear

@MainActor
struct ItemHomeIntegrationTests {
    @Test func selectionReevaluatesOneForecastWithoutExtraProviderOrLocationRequests() async throws {
        let forecast = fixture()
        let now = forecast.metadata.fetchedAt
        let weather = ItemHomeCountingWeatherProvider(forecast: forecast)
        let store = MemoryCacheDataStore()
        let location = ItemHomeCountingLocationProvider(reading: LocationReading(
            identity: forecast.metadata.location, accuracyMeters: 10, timestamp: now
        ))
        let model = makeModel(forecast: forecast, store: store, weather: weather, location: location, now: { now })
        await model.loadIfNeeded()
        model.updateSelectedItems([.sunglasses, .raincoat])
        let results = try #require(result(model)).itemResults
        #expect(results.map(\.item) == [.raincoat, .sunglasses])
        #expect(results.allSatisfy { $0.evaluation != nil })
        model.updateSelectedItems([.gloves])
        model.updateSelectedItems([.leatherJacket, .sunglasses])
        model.updateSelectedItems([])
        #expect(model.selectedItems == [.leatherJacket, .sunglasses])
        #expect(await weather.requestCount == 1)
        #expect(location.requestCount == 1)
    }

    @Test func validNonJacketAdviceSurvivesMissingJacketInputsAndMissingSkyIsIndependent() async throws {
        for missingTemperature in [false, true] {
            let forecast = fixture(missingTemperature: missingTemperature, missingSky: !missingTemperature)
            let now = forecast.metadata.fetchedAt
            let store = MemoryCacheDataStore()
            let model = makeModel(forecast: forecast, store: store, weather: FixedWeatherProvider(result: .success(forecast)), now: { now })
            model.updateSelectedItems([.leatherJacket, .sunglasses, .raincoat])
            await model.loadIfNeeded()
            let presentation = try #require(result(model))
            #expect(presentation.itemResults.first { $0.item == .raincoat }?.evaluation?.verdict == .useful)
            #expect((presentation.itemResults.first { $0.item == .leatherJacket }?.evaluation == nil) == missingTemperature)
            #expect((presentation.itemResults.first { $0.item == .sunglasses }?.evaluation == nil) == !missingTemperature)
            #expect(await WeatherCache(store: store).validForecast(at: now, for: forecast.metadata.location) != nil)
        }
    }

    @Test func selectionCannotResurrectAnExpiredForecast() async throws {
        let forecast = fixture()
        let clock = ItemHomeClock(forecast.metadata.fetchedAt)
        let weather = ItemHomeCountingWeatherProvider(forecast: forecast)
        let model = makeModel(forecast: forecast, store: MemoryCacheDataStore(), weather: weather, now: { clock.value })
        await model.loadIfNeeded()
        clock.advance(90 * 60 + 0.001)
        model.updateSelectedItems([.sunglasses])
        #expect(model.state == .weatherDataExpired)
        #expect(await weather.requestCount == 1)
    }

    @Test func failedRefreshRetainsSelectedItemResultsOnlyWithinExistingFreshnessLimit() async throws {
        let forecast = fixture(missingTemperature: true)
        let now = forecast.metadata.fetchedAt.addingTimeInterval(20 * 60)
        let store = MemoryCacheDataStore()
        await WeatherCache(store: store).save(forecast)
        await LocationCache(store: store).save(LocationReading(identity: forecast.metadata.location, accuracyMeters: 10, timestamp: now))
        let model = makeModel(forecast: forecast, store: store, weather: FixedWeatherProvider(result: .failure(.network)), now: { now })
        model.updateSelectedItems([.sunglasses])
        await model.loadIfNeeded()
        let presentation = try #require(result(model))
        #expect(presentation.refreshFailed)
        #expect(presentation.isUsingSavedWeather)
        #expect(presentation.itemResults.map(\.item) == [.sunglasses])
        #expect(presentation.itemResults[0].evaluation?.verdict == .useful)
        #expect(presentation.hours.isEmpty) // Jacket data is unavailable, not an app-wide blocker.
    }

    @Test func crossingLocalHourRecountsRemainingUsefulnessWithoutEarlyWeatherRefresh() async throws {
        let start = ItemEngineFixtures.dayEnd.addingTimeInterval(-3 * 3_600)
        let fetchedAt = start.addingTimeInterval(59 * 60)
        let forecast = NormalizedForecast(
            hours: (0..<3).map { index in
                ItemEngineFixtures.hour(at: start.addingTimeInterval(Double(index) * 3_600), sky: index < 2 ? .clear : .overcast)
            }, metadata: ForecastMetadata(fetchedAt: fetchedAt, location: LocationIdentity(latitude: 50.85, longitude: 4.35))
        )
        let clock = ItemHomeClock(fetchedAt)
        let weather = ItemHomeCountingWeatherProvider(forecast: forecast)
        let model = makeModel(forecast: forecast, store: MemoryCacheDataStore(), weather: weather, now: { clock.value })
        model.updateSelectedItems([.sunglasses])
        await model.loadIfNeeded()
        #expect(result(model)?.itemResults[0].evaluation?.verdict == .useful)
        clock.advance(2 * 60)
        await model.appBecameActive()
        #expect(result(model)?.itemResults[0].evaluation?.verdict == .brieflyUseful)
        #expect(result(model)?.evaluationHour == start.addingTimeInterval(3_600))
        #expect(await weather.requestCount == 1)
    }

    @Test func invalidLiveInputsPreserveUsableFallbackButOneUnavailableItemDoesNotBlockOthers() async throws {
        let saved = fixture()
        let now = saved.metadata.fetchedAt.addingTimeInterval(20 * 60)
        let incomplete = fixture(missingSky: true)
        let live = NormalizedForecast(hours: incomplete.hours, metadata: ForecastMetadata(fetchedAt: now, location: saved.metadata.location))
        let selections: [[PredefinedItem]] = [[.sunglasses], [.raincoat, .sunglasses]]
        for selected in selections {
            let store = MemoryCacheDataStore()
            await WeatherCache(store: store).save(saved)
            let model = makeModel(forecast: saved, store: store, weather: FixedWeatherProvider(result: .success(live)), now: { now })
            model.updateSelectedItems(selected)
            await model.loadIfNeeded()
            let presentation = try #require(result(model))
            if selected.count == 1 {
                #expect(presentation.refreshFailed)
                #expect(presentation.isUsingSavedWeather)
                #expect(presentation.itemResults[0].evaluation?.verdict == .useful)
                #expect(await WeatherCache(store: store).validForecast(at: now, for: saved.metadata.location)?.metadata.fetchedAt == saved.metadata.fetchedAt)
            } else {
                #expect(!presentation.refreshFailed)
                #expect(!presentation.isUsingSavedWeather)
                #expect(presentation.itemResults[0].evaluation?.verdict == .useful)
                #expect(presentation.itemResults[1].evaluation == nil)
                #expect(await WeatherCache(store: store).validForecast(at: now, for: saved.metadata.location)?.metadata.fetchedAt == now)
            }
        }
    }

    @Test func selectionChangedDuringCacheSaveIsNotOverwrittenByEarlierPresentation() async throws {
        let forecast = fixture()
        let now = forecast.metadata.fetchedAt
        let store = DeferredItemHomeCacheStore()
        let weather = ItemHomeCountingWeatherProvider(forecast: forecast)
        let model = RecommendationViewModel(
            locationProvider: FixedLocationProvider(result: .success(LocationReading(
                identity: forecast.metadata.location, accuracyMeters: 10, timestamp: now
            ))), weatherProvider: weather,
            locationCache: LocationCache(store: store), weatherCache: WeatherCache(store: store),
            localityResolver: ItemHomeTestLocalityResolver(), now: { now }
        )
        let load = Task { await model.loadIfNeeded() }
        while !(await store.waitingToSave) { await Task.yield() }
        model.updateSelectedItems([.sunglasses])
        await store.resumeSave()
        await load.value
        #expect(result(model)?.itemResults.map(\.item) == [.sunglasses])
        #expect(result(model)?.itemResults[0].evaluation?.verdict == .useful)
        #expect(await weather.requestCount == 1)
    }

    @Test func lateNightKeepsPlanningPeriodsButDailyAnswersOnlyCountRemainingHours() async throws {
        let start = ItemEngineFixtures.dayEnd.addingTimeInterval(-18 * 3_600)
        let now = ItemEngineFixtures.dayEnd.addingTimeInterval(-1_800)
        let hours: [HourlyWeather] = (6..<24).map { hour in
            let timestamp = start.addingTimeInterval(Double(hour - 6) * 3_600)
            return ItemEngineFixtures.hour(
                at: timestamp, amount: hour == 23 ? 1 : 0,
                daylight: hour < 19, sky: (12..<15).contains(hour) ? .clear : .overcast
            )
        }
        let forecast = NormalizedForecast(hours: hours, metadata: ForecastMetadata(
            fetchedAt: now, location: LocationIdentity(latitude: 50.85, longitude: 4.35)
        ))
        let weather = ItemHomeCountingWeatherProvider(forecast: forecast)
        let model = makeModel(forecast: forecast, store: MemoryCacheDataStore(), weather: weather, now: { now })
        model.updateSelectedItems([.leatherJacket, .sunglasses])
        await model.loadIfNeeded()
        let display = try #require(result(model))
        #expect(display.itemResults[0].evaluation?.hours.count == 1)
        #expect(display.itemResults[1].evaluation?.verdict == .notNeeded)
        #expect(display.itemResults[1].evaluation?.qualifyingHours.isEmpty == true)
        #expect(display.itemPlanningResults[0].evaluation?.periods.count == 2)
        #expect(display.itemPlanningResults[1].evaluation?.hours.count == 18)
        #expect(display.itemPlanningResults[1].evaluation?.periods.count == 3)
        #expect(display.itemPlanningResults[1].evaluation?.qualifyingHours.count == 3)
        let spoken = ItemHomePresentation(result: display.itemResults[1]).overviewAccessibilityLabel(
            dayParts: FixedDayPartPresentation.make(from: try #require(display.itemPlanningResults[1].evaluation), at: now)
        )
        #expect(spoken.contains("Not needed today"))
        #expect(spoken.contains("Afternoon, 12–18, YES"))
        #expect(spoken.contains("12:00–15:00, Useful"))
        #expect(spoken.contains("finished for today"))
        model.updateSelectedItems([.raincoat])
        #expect(result(model)?.itemResults[0].evaluation?.verdict == .brieflyUseful)
        #expect(result(model)?.itemPlanningResults[0].item == .raincoat)
        #expect(result(model)?.itemPlanningResults[0].evaluation?.periods.count == 2)
        #expect(await weather.requestCount == 1)
    }

    @Test func unavailablePastInputsDoNotSuppressValidRemainingItemAdvice() async throws {
        let start = ItemEngineFixtures.dayEnd.addingTimeInterval(-18 * 3_600)
        let now = ItemEngineFixtures.dayEnd.addingTimeInterval(-1_800)
        let hours: [HourlyWeather] = (6..<24).map { hour in
            ItemEngineFixtures.hour(at: start.addingTimeInterval(Double(hour - 6) * 3_600), daylight: [8, 9].contains(hour) ? nil : true)
        }
        let forecast = NormalizedForecast(hours: hours, metadata: ForecastMetadata(
            fetchedAt: now, location: LocationIdentity(latitude: 50.85, longitude: 4.35)
        ))
        let model = makeModel(forecast: forecast, store: MemoryCacheDataStore(), weather: FixedWeatherProvider(result: .success(forecast)), now: { now })
        model.updateSelectedItems([.leatherJacket, .sunglasses])
        await model.loadIfNeeded()
        let display = try #require(result(model))
        #expect(display.itemResults.allSatisfy { $0.evaluation != nil })
        #expect(display.itemPlanningResults[0].evaluation != nil)
        #expect(display.itemPlanningResults[1].evaluation == nil)
    }

    private func result(_ model: RecommendationViewModel) -> DailyRecommendationPresentation? {
        guard case .result(let presentation) = model.state else { return nil }
        return presentation
    }

    private func makeModel(
        forecast: NormalizedForecast, store: MemoryCacheDataStore, weather: any WeatherProvider,
        location: (any LocationProvider)? = nil,
        now: @escaping @Sendable () -> Date
    ) -> RecommendationViewModel {
        RecommendationViewModel(
            locationProvider: location ?? FixedLocationProvider(result: .success(LocationReading(
                identity: forecast.metadata.location, accuracyMeters: 10, timestamp: now()
            ))), weatherProvider: weather,
            locationCache: LocationCache(store: store), weatherCache: WeatherCache(store: store),
            localityResolver: ItemHomeTestLocalityResolver(), now: now
        )
    }

    private func fixture(missingTemperature: Bool = false, missingSky: Bool = false) -> NormalizedForecast {
        let start = ItemEngineFixtures.dayEnd.addingTimeInterval(-3 * 3_600)
        return NormalizedForecast(
            hours: (0..<3).map { offset in
                ItemEngineFixtures.hour(
                    at: start.addingTimeInterval(Double(offset) * 3_600), actual: missingTemperature ? nil : 12,
                    amount: 1, sky: missingSky ? nil : .clear
                )
            },
            metadata: ForecastMetadata(fetchedAt: start.addingTimeInterval(1_800), location: LocationIdentity(latitude: 50.85, longitude: 4.35))
        )
    }
}

private actor ItemHomeCountingWeatherProvider: WeatherProvider {
    let forecast: NormalizedForecast
    private(set) var requestCount = 0
    init(forecast: NormalizedForecast) { self.forecast = forecast }
    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        requestCount += 1
        return forecast
    }
}

private final class ItemHomeClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date
    init(_ date: Date) { self.date = date }
    var value: Date { lock.withLock { date } }
    func advance(_ seconds: TimeInterval) { lock.withLock { date = date.addingTimeInterval(seconds) } }
}

private actor DeferredItemHomeCacheStore: CacheDataStore {
    private var values: [String: Data] = [:]
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var waitingToSave = false
    func data(forKey key: String) -> Data? { values[key] }
    func set(_ data: Data?, forKey key: String) async {
        if key == WeatherCache.storageKey, data != nil {
            waitingToSave = true
            await withCheckedContinuation { continuation = $0 }
        }
        values[key] = data
    }
    func resumeSave() { continuation?.resume(); continuation = nil }
}

@MainActor
private final class ItemHomeCountingLocationProvider: LocationProvider {
    let reading: LocationReading
    private(set) var requestCount = 0
    init(reading: LocationReading) { self.reading = reading }
    func currentLocation() async throws -> LocationReading { requestCount += 1; return reading }
}

@MainActor
private struct ItemHomeTestLocalityResolver: LocalityResolving {
    func locality(for location: LocationIdentity) async -> String? { "Test locality" }
}
