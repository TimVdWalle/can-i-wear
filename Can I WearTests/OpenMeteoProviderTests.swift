import Foundation
import Testing
@testable import Can_I_Wear

struct OpenMeteoProviderTests {
    @Test func requestsRequiredHourlyValuesAndTimezone() throws {
        let location = LocationIdentity(latitude: 50.85, longitude: 4.35)
        let request = try OpenMeteoProvider.makeRequest(for: location)
        let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        #expect(components.scheme == "https")
        #expect(components.host == "api.open-meteo.com")
        #expect(query["latitude"] == "50.85")
        #expect(query["longitude"] == "4.35")
        #expect(query["timezone"] == "auto")
        #expect(query["timeformat"] == "unixtime")
        #expect(query["hourly"]?.contains("precipitation_probability") == true)
        #expect(query["hourly"]?.contains("apparent_temperature") == true)
    }

    @Test func mapsHourlyResponseAndPreservesMissingValues() async throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let payload = """
        {
          "timezone": "Europe/Brussels",
          "hourly": {
            "time": [1700000000, 1700003600],
            "temperature_2m": [12.5, null],
            "apparent_temperature": [11.0, null],
            "precipitation_probability": [75, null],
            "precipitation": [2.4, null],
            "rain": [2.4, null],
            "showers": [0, null],
            "snowfall": [0, null],
            "weather_code": [63, null]
          }
        }
        """.data(using: .utf8)!
        let client = FixedHTTPClient(statusCode: 200, data: payload)
        let provider = OpenMeteoProvider(client: client, now: { fetchedAt })

        let forecast = try await provider.hourlyForecast(
            for: LocationIdentity(latitude: 50.85, longitude: 4.35)
        )

        #expect(forecast.hours.count == 2)
        #expect(forecast.hours[0].actualTemperatureCelsius == 12.5)
        #expect(forecast.hours[0].apparentTemperatureCelsius == 11)
        #expect(forecast.hours[0].precipitationAmountMillimeters == 2.4)
        #expect(forecast.hours[0].precipitationChanceFraction == 0.75)
        #expect(forecast.hours[0].precipitationType == .rain)
        #expect(forecast.hours[0].timezoneIdentifier == "Europe/Brussels")
        #expect(forecast.hours[1].actualTemperatureCelsius == nil)
        #expect(forecast.hours[1].precipitationAmountMillimeters == nil)
        #expect(forecast.hours[1].precipitationChanceFraction == nil)
        #expect(forecast.metadata.fetchedAt == fetchedAt)
    }

    @Test func mapsHTTPAndNetworkFailures() async {
        let location = LocationIdentity(latitude: 0, longitude: 0)

        await #expect(throws: WeatherProviderError.unavailable) {
            try await OpenMeteoProvider(
                client: FixedHTTPClient(statusCode: 500, data: Data())
            ).hourlyForecast(for: location)
        }
        await #expect(throws: WeatherProviderError.network) {
            try await OpenMeteoProvider(
                client: ThrowingHTTPClient(error: URLError(.notConnectedToInternet))
            ).hourlyForecast(for: location)
        }
    }
}

private struct FixedHTTPClient: HTTPClient {
    let statusCode: Int
    let data: Data

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}

private struct ThrowingHTTPClient: HTTPClient {
    let error: any Error & Sendable

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw error
    }
}
