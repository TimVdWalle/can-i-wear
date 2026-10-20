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
        #expect(query["wind_speed_unit"] == "kmh")
        #expect(query["hourly"]?.contains("precipitation_probability") == true)
        #expect(query["hourly"]?.contains("apparent_temperature") == true)
        #expect(query["hourly"]?.contains("weather_code") == true)
        #expect(query["hourly"]?.contains("is_day") == true)
        #expect(query["hourly"]?.contains("cloud_cover") == true)
        #expect(query["hourly"]?.contains("uv_index") == true)
        #expect(query["precipitation_unit"] == "mm")
        #expect(query["hourly"]?.contains("wind_speed_10m") == true)
        #expect(query["hourly"]?.contains("wind_gusts_10m") == true)
    }

    @Test func mapsHourlyResponseAndPreservesMissingValues() async throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let payload = """
        {
          "timezone": "Europe/Brussels",
          "hourly": {
            "time": [1700000000, 1700003600, 1700007200],
            "temperature_2m": [12.5, null, 10],
            "apparent_temperature": [11.0, null, 9],
            "precipitation_probability": [99, 75, null],
            "precipitation": [9.9, 2.4, null],
            "rain": [9.9, 2.4, null],
            "showers": [0, 0, null],
            "snowfall": [0, 0, null],
            "weather_code": [63, null, 3],
            "wind_speed_10m": [14.5, null, 5],
            "wind_gusts_10m": [90, 28.0, null],
            "is_day": [1, null, 0],
            "cloud_cover": [100, null, 5],
            "uv_index": [2.5, null, 0]
          }
        }
        """.data(using: .utf8)!
        let client = FixedHTTPClient(statusCode: 200, data: payload)
        let provider = OpenMeteoProvider(client: client, now: { fetchedAt })

        let forecast = try await provider.hourlyForecast(
            for: LocationIdentity(latitude: 50.85, longitude: 4.35)
        )

        #expect(forecast.hours.count == 3)
        #expect(forecast.hours[0].actualTemperatureCelsius == 12.5)
        #expect(forecast.hours[0].apparentTemperatureCelsius == 11)
        #expect(forecast.hours[0].precipitationAmountMillimeters == 2.4)
        #expect(forecast.hours[0].precipitationChanceFraction == 0.75)
        #expect(forecast.hours[0].precipitationType == .rain)
        #expect(forecast.hours[0].timezoneIdentifier == "Europe/Brussels")
        #expect(forecast.hours[0].windSpeedKilometersPerHour == 14.5)
        #expect(forecast.hours[0].windGustKilometersPerHour == 28)
        #expect(forecast.hours[0].isDaylight == true)
        #expect(forecast.hours[0].skyCondition == .overcast)
        #expect(forecast.hours[0].uvIndex == 2.5)
        #expect(forecast.hours[1].actualTemperatureCelsius == nil)
        #expect(forecast.hours[1].precipitationAmountMillimeters == nil)
        #expect(forecast.hours[1].precipitationChanceFraction == nil)
        #expect(forecast.hours[1].windSpeedKilometersPerHour == nil)
        #expect(forecast.hours[1].windGustKilometersPerHour == nil)
        #expect(forecast.hours[1].isDaylight == nil)
        #expect(forecast.hours[1].skyCondition == nil)
        #expect(forecast.hours[1].uvIndex == nil)
        #expect(forecast.metadata.fetchedAt == fetchedAt)
    }

    @Test func mapsOnlyExplicitFogAndRimeFogCodesAsMoistureHazards() async throws {
        let payload = """
        {
          "timezone": "Europe/Brussels",
          "hourly": {
            "time": [1700000000, 1700003600, 1700007200, 1700010800],
            "temperature_2m": [12, 12, 12, 12],
            "apparent_temperature": [12, 12, 12, 12],
            "precipitation_probability": [0, 0, 0, 0],
            "precipitation": [0, 0, 0, 0],
            "rain": [0, 0, 0, 0],
            "showers": [0, 0, 0, 0],
            "snowfall": [0, 0, 0, 0],
            "weather_code": [45, 48, 3, null]
          }
        }
        """.data(using: .utf8)!

        let forecast = try await OpenMeteoProvider(
            client: FixedHTTPClient(statusCode: 200, data: payload)
        ).hourlyForecast(for: LocationIdentity(latitude: 50.85, longitude: 4.35))

        #expect(forecast.hours.map(\.fogOrMistCondition) == [
            .fog,
            .depositingRimeFog,
            FogOrMistCondition.none,
            nil
        ])
    }

    @Test func alignsAccumulationsWithoutShiftingInstantaneousInputs() async throws {
        let payload = """
        {
          "timezone": "Europe/Brussels",
          "hourly": {
            "time": [1700000000, 1700003600],
            "temperature_2m": [12, 30],
            "apparent_temperature": [11, 31],
            "precipitation": [0, 1],
            "precipitation_probability": [0, 70],
            "rain": [0, 1],
            "weather_code": [0, 0],
            "wind_speed_10m": [10, 40],
            "wind_gusts_10m": [11, 45]
          }
        }
        """.data(using: .utf8)!
        let forecast = try await OpenMeteoProvider(
            client: FixedHTTPClient(statusCode: 200, data: payload)
        ).hourlyForecast(for: LocationIdentity(latitude: 50.85, longitude: 4.35))
        let first = try #require(forecast.hours.first)

        // The second timestamp's accumulation describes the interval starting at the first.
        #expect(first.timestamp == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(first.precipitationAmountMillimeters == 1)
        #expect(first.precipitationChanceFraction == 0.7)
        #expect(first.precipitationType == .rain)
        #expect(first.actualTemperatureCelsius == 12)
        #expect(first.apparentTemperatureCelsius == 11)
        #expect(first.windSpeedKilometersPerHour == 10)
        #expect(first.windGustKilometersPerHour == 45)
        #expect(forecast.hours.last?.precipitationAmountMillimeters == nil)
        #expect(forecast.hours.last?.precipitationChanceFraction == nil)
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

struct OpenMeteoNormalizationTests {
    private let base = 1_700_000_000

    @Test func preservesExplicitSkyConditionsAndUsesUpstreamCloudCoverBoundaries() async throws {
        let cases: [(Int?, Double?, SkyCondition?)] = [
            (0, 100, .clear), (1, nil, .mainlyClear), (2, nil, .partlyCloudy),
            (3, 0, .overcast), (45, 0, .fogOrMist), (48, nil, .fogOrMist),
            (61, 0, .clear), (61, 19.99, .clear), (65, 20, .mainlyClear),
            (51, 49.99, .mainlyClear), (71, 50, .partlyCloudy),
            (95, 79.99, .partlyCloudy), (nil, 80, .overcast), (nil, 100, .overcast),
            (999, nil, nil), (nil, -1, nil), (61, 101, nil), (nil, nil, nil)
        ]
        let forecast = try await fixture(
            times: cases.indices.map { base + $0 * 3_600 },
            fields: [
                "weather_code": cases.map { $0.0.map { $0 as Any } ?? NSNull() },
                "cloud_cover": cases.map { $0.1.map { $0 as Any } ?? NSNull() }
            ]
        )
        let expected = cases.map { $0.2 }
        #expect(forecast.hours.map(\.skyCondition) == expected)
        // Cloud cover is never used to invent a fog/mist hazard for Leather Jacket.
        #expect(forecast.hours[6].fogOrMistCondition == FogOrMistCondition.none)
        #expect(forecast.hours[12].fogOrMistCondition == nil)
    }

    @Test func preservesDaylightAndHourlyUVWithoutInventingMissingSignals() async throws {
        let forecast = try await fixture(
            times: (0..<5).map { base + $0 * 3_600 },
            fields: [
                "is_day": [0, 1, 2, NSNull(), 1] as [Any],
                "uv_index": [0, 6, -1, NSNull(), 5.9] as [Any],
                "weather_code": [0, 0, 0, 0, 0]
            ]
        )
        #expect(forecast.hours.map(\.isDaylight) == [false, true, nil, nil, true])
        #expect(forecast.hours.map(\.uvIndex) == [0, 6, nil, nil, 5.9])
        #expect(forecast.hours[0].skyCondition == .clear)
        #expect(forecast.hours[0].isDaylight == false) // Clear sky is not a sunny night.

        let absent = try await fixture(times: [base], fields: [:])
        #expect(absent.hours[0].isDaylight == nil)
        #expect(absent.hours[0].skyCondition == nil)
        #expect(absent.hours[0].uvIndex == nil)
    }

    @Test func matchesAccumulationsByTimestampRatherThanArrayPosition() async throws {
        let forecast = try await fixture(
            times: [base + 7_200, base, base + 3_600],
            fields: [
                "temperature_2m": [14, 12, 13],
                "precipitation": [2, 99, 1],
                "precipitation_probability": [20, 99, 10],
                "rain": [2, 99, 1]
            ]
        )
        #expect(forecast.hours.map(\.actualTemperatureCelsius) == [14, 12, 13])
        #expect(forecast.hours.map(\.precipitationAmountMillimeters) == [nil, 1, 2])
        #expect(forecast.hours.map(\.precipitationChanceFraction) == [nil, 0.1, 0.2])
    }

    @Test func doesNotFillMissingOrAmbiguousAccumulationIntervals() async throws {
        for times in [[base, base + 7_200], [base, base + 3_600, base + 3_600]] {
            let forecast = try await fixture(
                times: times,
                fields: [
                    "temperature_2m": Array(repeating: 12, count: times.count),
                    "precipitation": Array(repeating: 1, count: times.count),
                    "precipitation_probability": Array(repeating: 50, count: times.count)
                ]
            )
            #expect(forecast.hours[0].actualTemperatureCelsius == 12)
            #expect(forecast.hours[0].precipitationAmountMillimeters == nil)
            #expect(forecast.hours[0].precipitationChanceFraction == nil)
        }
    }

    @Test func retainsTotalWaterEquivalentAndAlignedPrecipitationComponents() async throws {
        let forecast = try await fixture(
            times: (0..<5).map { base + $0 * 3_600 },
            fields: [
                "precipitation": [0, 0.5, 0.5, 0.5, 0.5],
                "precipitation_probability": [0, 30, 30, 30, 30],
                "rain": [0, 0.5, 0, 0.2, 0],
                "snowfall": [0, 0, 7, 2, 0],
                "weather_code": [0, 0, 0, 96, 0]
            ]
        )
        #expect(Array(forecast.hours.prefix(4)).map(\.precipitationAmountMillimeters) == [0.5, 0.5, 0.5, 0.5])
        #expect(Array(forecast.hours.prefix(4)).map(\.precipitationType) == [.rain, .snow, .mixed, .hail])
        // The provider total is authoritative; never add rain or convert snow depth into it.
        #expect(forecast.hours[1].precipitationAmountMillimeters == 0.5)
    }

    @Test func rainTransitionProducesAdviceForTheCorrectLocalHours() async throws {
        let calendar = brusselsCalendar()
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 9)))
        let day = try #require(calendar.dateInterval(of: .day, for: start))
        let count = Int(day.end.timeIntervalSince(start) / 3_600)
        var amounts = Array(repeating: 0.0, count: count + 1)
        for index in 4...6 { amounts[index] = 1 } // 12:00–15:00, stamped 13:00–16:00.
        let forecast = try await dayFixture(start: start, amounts: amounts)
        let evaluation = try #require(DailyRecommendationEngine().evaluateHours(
            forecast, now: start.addingTimeInterval(1_800)
        ))
        let wetHours = evaluation.hours.filter { $0.recommendation.level == .avoid }
        #expect(wetHours.map(\.timestamp) == (3...5).map { start.addingTimeInterval(Double($0) * 3_600) })
        let avoidance = DayPeriodEngine().periods(for: evaluation).filter { $0.recommendation.level == .avoid }
        #expect(avoidance.count == 1)
        #expect(avoidance.first?.interval == DateInterval(
            start: start.addingTimeInterval(3 * 3_600), duration: 3 * 3_600
        ))
    }

    @Test func finalLocalHourUsesTheFollowingMidnightAccumulationNotPastRain() async throws {
        let calendar = brusselsCalendar()
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 23)))
        for upcomingAmount in [0.0, 1.0] {
            let forecast = try await dayFixture(start: start, amounts: [1 - upcomingAmount, upcomingAmount])
            let evaluation = try #require(DailyRecommendationEngine().evaluateHours(
                forecast, now: start.addingTimeInterval(1_800)
            ))
            #expect(evaluation.hours.count == 1)
            #expect(evaluation.hours[0].recommendation.level == (upcomingAmount > 0 ? .avoid : .okay))
            #expect(evaluation.interval == DateInterval(start: start, duration: 3_600))
        }
    }

    @Test func accumulationAlignmentRespectsBothDSTTransitions() async throws {
        let calendar = brusselsCalendar()
        for (month, day, expectedHours) in [(3, 29, 23), (10, 25, 25)] {
            let start = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: day)))
            let interval = try #require(calendar.dateInterval(of: .day, for: start))
            let count = Int(interval.duration / 3_600)
            var amounts = Array(repeating: 0.0, count: count + 1)
            amounts[count] = 1
            let forecast = try await dayFixture(start: start, amounts: amounts)
            let evaluation = try #require(DailyRecommendationEngine().evaluateHours(forecast, now: start))
            #expect(evaluation.hours.count == expectedHours)
            #expect(evaluation.interval == interval)
            #expect(evaluation.hours.last?.timestamp == interval.end.addingTimeInterval(-3_600))
            #expect(evaluation.hours.last?.recommendation.level == .avoid)
            #expect(evaluation.hours.dropLast().allSatisfy { $0.recommendation.level == .okay })
        }
    }

    private func brusselsCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Brussels")!
        return calendar
    }

    private func dayFixture(start: Date, amounts: [Double]) async throws -> NormalizedForecast {
        try await fixture(
            times: amounts.indices.map { Int(start.timeIntervalSince1970) + $0 * 3_600 },
            fields: [
                "temperature_2m": Array(repeating: 12, count: amounts.count),
                "apparent_temperature": Array(repeating: 12, count: amounts.count),
                "weather_code": Array(repeating: 0, count: amounts.count),
                "precipitation": amounts,
                "rain": amounts,
                "precipitation_probability": Array(repeating: 0, count: amounts.count)
            ]
        )
    }

    private func fixture(times: [Int], fields: [String: Any]) async throws -> NormalizedForecast {
        var hourly = fields
        hourly["time"] = times
        let data = try JSONSerialization.data(withJSONObject: [
            "timezone": "Europe/Brussels", "hourly": hourly
        ])
        let fetchedAt = Date(timeIntervalSince1970: TimeInterval(times.first ?? 0))
        return try await OpenMeteoProvider(
            client: FixedHTTPClient(statusCode: 200, data: data), now: { fetchedAt }
        ).hourlyForecast(for: LocationIdentity(latitude: 50.85, longitude: 4.35))
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
