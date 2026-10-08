import Foundation
import Testing
import WeatherKit
@testable import Can_I_Wear

struct WeatherKitProviderTests {
    @Test func mapsHourlyValuesIntoNormalizedUnits() async throws {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let location = LocationIdentity(latitude: 50.85, longitude: 4.35)
        let service = FixedWeatherKitService(result: .success([
            WeatherKitHourlySnapshot(
                timestamp: timestamp,
                actualTemperature: Measurement(value: 50, unit: .fahrenheit),
                apparentTemperature: Measurement(value: 48.2, unit: .fahrenheit),
                precipitationAmount: Measurement(value: 0.1, unit: .inches),
                precipitation: .rain,
                precipitationChance: 0.75,
                condition: .foggy,
                windSpeed: Measurement(value: 10, unit: .milesPerHour),
                windGust: Measurement(value: 20, unit: .milesPerHour)
            )
        ]))
        let provider = WeatherKitProvider(service: service, now: { fetchedAt })

        let forecast = try await provider.hourlyForecast(for: location)
        let hour = try #require(forecast.hours.first)

        #expect(abs((hour.actualTemperatureCelsius ?? 0) - 10) < 0.0001)
        #expect(abs((hour.apparentTemperatureCelsius ?? 0) - 9) < 0.0001)
        #expect(abs((hour.precipitationAmountMillimeters ?? 0) - 2.54) < 0.0001)
        #expect(hour.precipitationType == .rain)
        #expect(hour.precipitationChanceFraction == 0.75)
        #expect(hour.fogOrMistCondition == .fog)
        #expect(abs((hour.windSpeedKilometersPerHour ?? 0) - 16.0934) < 0.0001)
        #expect(abs((hour.windGustKilometersPerHour ?? 0) - 32.1868) < 0.0001)
        #expect(hour.timestamp == timestamp)
        #expect(hour.timezoneIdentifier == nil)
        #expect(forecast.metadata.fetchedAt == fetchedAt)
        #expect(forecast.metadata.location == location)
    }

    @Test func preservesUnavailableWeatherKitValues() async throws {
        let snapshot = WeatherKitHourlySnapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            actualTemperature: nil,
            apparentTemperature: nil,
            precipitationAmount: nil,
            precipitation: nil,
            precipitationChance: nil
        )
        let provider = WeatherKitProvider(
            service: FixedWeatherKitService(result: .success([snapshot]))
        )

        let forecast = try await provider.hourlyForecast(
            for: LocationIdentity(latitude: 0, longitude: 0)
        )
        let hour = try #require(forecast.hours.first)

        #expect(hour.actualTemperatureCelsius == nil)
        #expect(hour.apparentTemperatureCelsius == nil)
        #expect(hour.precipitationAmountMillimeters == nil)
        #expect(hour.precipitationType == nil)
        #expect(hour.precipitationChanceFraction == nil)
        #expect(hour.fogOrMistCondition == nil)
        #expect(hour.windSpeedKilometersPerHour == nil)
        #expect(hour.windGustKilometersPerHour == nil)
    }

    @Test func mapsProviderFailures() async {
        let location = LocationIdentity(latitude: 0, longitude: 0)

        await #expect(throws: WeatherProviderError.unauthorized) {
            try await WeatherKitProvider(
                service: FixedWeatherKitService(result: .failure(WeatherError.permissionDenied))
            ).hourlyForecast(for: location)
        }
        await #expect(throws: WeatherProviderError.network) {
            try await WeatherKitProvider(
                service: FixedWeatherKitService(result: .failure(URLError(.notConnectedToInternet)))
            ).hourlyForecast(for: location)
        }
    }
}

private struct FixedWeatherKitService: WeatherKitServing {
    let result: Result<[WeatherKitHourlySnapshot], any Error>

    func hourlyWeather(for location: LocationIdentity) async throws -> [WeatherKitHourlySnapshot] {
        try result.get()
    }
}
