import Foundation
import Testing
@testable import Can_I_Wear

struct ForecastCacheTests {
    private let now = Date(timeIntervalSince1970: 1_791_203_400)
    private let currentHour = Date(timeIntervalSince1970: 1_791_201_600)
    private let location = LocationIdentity(latitude: 50.85, longitude: 4.35)

    @Test func locationIsReusableThroughInclusiveFreshnessBoundary() async {
        let store = MemoryCacheDataStore()
        let first = LocationCache(store: store)
        let reading = LocationReading(
            identity: location,
            accuracyMeters: 5_000,
            timestamp: now.addingTimeInterval(-30 * 60)
        )
        await first.save(reading)

        let afterRelaunch = LocationCache(store: store)
        #expect(await afterRelaunch.validReading(at: now) == reading)
        #expect(await afterRelaunch.validReading(at: now.addingTimeInterval(0.001)) == nil)
    }

    @Test func locationCacheRejectsFutureAndInadequateReadings() async {
        let futureStore = MemoryCacheDataStore()
        let futureCache = LocationCache(store: futureStore)
        await futureCache.save(LocationReading(
            identity: location,
            accuracyMeters: 25,
            timestamp: now.addingTimeInterval(1)
        ))

        let inaccurateStore = MemoryCacheDataStore()
        let inaccurateCache = LocationCache(store: inaccurateStore)
        await inaccurateCache.save(LocationReading(
            identity: location,
            accuracyMeters: 5_001,
            timestamp: now
        ))

        #expect(await futureCache.validReading(at: now) == nil)
        #expect(await inaccurateCache.validReading(at: now) == nil)
    }

    @Test func weatherIsReusableThroughInclusiveFreshnessBoundary() async {
        let store = MemoryCacheDataStore()
        let cache = WeatherCache(store: store)
        let forecast = forecast(fetchedAt: now.addingTimeInterval(-30 * 60))
        await cache.save(forecast)

        #expect(await cache.validForecast(at: now, for: location) == forecast)
        #expect(await cache.validForecast(
            at: now.addingTimeInterval(0.001),
            for: location
        ) == nil)
        #expect(await cache.lookup(
            at: now.addingTimeInterval(0.001),
            for: location
        ) == .expired)
    }

    @Test func weatherCacheRequiresLocationWithinFiveKilometers() async {
        let store = MemoryCacheDataStore()
        let cache = WeatherCache(store: store)
        await cache.save(forecast())

        let nearby = LocationIdentity(latitude: 50.86, longitude: 4.35)
        let tooFar = LocationIdentity(latitude: 50.90, longitude: 4.35)
        #expect(await cache.validForecast(at: now, for: nearby) != nil)
        #expect(await cache.validForecast(at: now, for: tooFar) == nil)
    }

    @Test func weatherCacheRejectsMalformedStorageAndWrongDayCoverage() async throws {
        let malformedStore = MemoryCacheDataStore()
        await malformedStore.set(Data("not-json".utf8), forKey: "latestNormalizedForecast")
        #expect(await WeatherCache(store: malformedStore).validForecast(
            at: now,
            for: location
        ) == nil)

        let oldDayStore = MemoryCacheDataStore()
        let oldDayCache = WeatherCache(store: oldDayStore)
        let oldHours = [hour(at: currentHour.addingTimeInterval(-24 * 3_600))]
        await oldDayCache.save(NormalizedForecast(
            hours: oldHours,
            metadata: ForecastMetadata(fetchedAt: now.addingTimeInterval(-10 * 60), location: location)
        ))
        #expect(await oldDayCache.validForecast(at: now, for: location) == nil)
    }

    private func forecast(fetchedAt: Date? = nil) -> NormalizedForecast {
        NormalizedForecast(
            hours: (0..<10).map { hour(at: currentHour.addingTimeInterval(TimeInterval($0 * 3_600))) },
            metadata: ForecastMetadata(fetchedAt: fetchedAt ?? now, location: location)
        )
    }

    private func hour(at timestamp: Date) -> HourlyWeather {
        HourlyWeather(
            timestamp: timestamp,
            timezoneIdentifier: "Europe/Brussels",
            actualTemperatureCelsius: 12,
            apparentTemperatureCelsius: 12,
            precipitationAmountMillimeters: 0,
            precipitationType: .none,
            precipitationChanceFraction: 0
        )
    }
}
