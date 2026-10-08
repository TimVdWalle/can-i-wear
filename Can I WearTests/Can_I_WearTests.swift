//
//  Can_I_WearTests.swift
//  Can I WearTests
//
//  Created by Tim Vande Walle on 04/10/2026.
//

import Testing
import Foundation
@testable import Can_I_Wear

struct Can_I_WearTests {

    @Test func normalizedForecastPreservesMissingInputsAndUnits() async throws {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let hour = HourlyWeather(
            timestamp: timestamp,
            timezoneIdentifier: "Europe/Brussels",
            actualTemperatureCelsius: 12.5,
            apparentTemperatureCelsius: nil,
            precipitationAmountMillimeters: nil,
            precipitationType: .rain,
            precipitationChanceFraction: 0.6,
            fogOrMistCondition: .fog
        )
        let location = LocationIdentity(latitude: 50.85, longitude: 4.35)
        let forecast = NormalizedForecast(
            hours: [hour],
            metadata: ForecastMetadata(fetchedAt: timestamp, location: location)
        )

        #expect(forecast.hours[0].actualTemperatureCelsius == 12.5)
        #expect(forecast.hours[0].apparentTemperatureCelsius == nil)
        #expect(forecast.hours[0].precipitationAmountMillimeters == nil)
        #expect(forecast.hours[0].precipitationChanceFraction == 0.6)
        #expect(forecast.hours[0].fogOrMistCondition == .fog)
        #expect(forecast.hours[0].timestamp == timestamp)
        #expect(forecast.hours[0].timezoneIdentifier == "Europe/Brussels")
        #expect(forecast.metadata.location == location)
    }

    @Test func fixedProvidersReturnDeterministicValues() async throws {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let location = LocationIdentity(latitude: 50.85, longitude: 4.35)
        let reading = LocationReading(identity: location, accuracyMeters: 10, timestamp: timestamp)
        let forecast = NormalizedForecast(
            hours: [],
            metadata: ForecastMetadata(fetchedAt: timestamp, location: location)
        )

        let fixedLocation = try await FixedLocationProvider(result: .success(reading)).currentLocation()
        let fixedForecast = try await FixedWeatherProvider(result: .success(forecast))
            .hourlyForecast(for: location)

        #expect(fixedLocation == reading)
        #expect(fixedForecast == forecast)
    }

    @Test func fixedProvidersPreserveExplicitFailures() async {
        await #expect(throws: LocationProviderError.permissionDenied) {
            try await FixedLocationProvider(result: .failure(.permissionDenied)).currentLocation()
        }
        await #expect(throws: WeatherProviderError.network) {
            try await FixedWeatherProvider(result: .failure(.network))
                .hourlyForecast(for: LocationIdentity(latitude: 0, longitude: 0))
        }
    }

}
