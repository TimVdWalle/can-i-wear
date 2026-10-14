import Foundation
import Testing
@testable import Can_I_Wear

struct HomePresentationTests {
    private let engine = DailyRecommendationEngine()

    @Test func mapsAllThreeStatusesAndShortReasons() {
        for (level, title, symbol, reason) in [
            (RecommendationLevel.okay, "OK", "checkmark", RecommendationReason.suitableTemperature),
            (.caution, "CAUTION", "exclamationmark", .warmTemperature),
            (.avoid, "AVOID", "xmark", .precipitation)
        ] {
            let result = RecommendationPresentation(recommendation: HourlyRecommendation(level: level, reason: reason))
            #expect(result.title == title)
            #expect(result.segmentSymbol == symbol)
            #expect(!result.reason.isEmpty)
        }
    }

    @Test func heroUsesExistingWorstHourPolicyAndPrecipitationReasonPriority() throws {
        var forecast = fixture()
        var hours = forecast.hours
        hours[8] = hour(hours[8].timestamp, temperature: 25)
        hours[10] = hour(hours[10].timestamp, fog: .fog)
        hours[17] = hour(hours[17].timestamp, amount: 1)
        forecast = NormalizedForecast(hours: hours, metadata: forecast.metadata)
        let result = try presentation(forecast)

        #expect(result.summary?.recommendation == engine.evaluate(forecast, now: forecast.hours[0].timestamp))
        #expect(result.summary?.recommendation == HourlyRecommendation(level: .avoid, reason: .precipitation))
        #expect(result.summary?.reason == "Precipitation could damage leather.")
        #expect(result.periods.first?.recommendation.level == .okay)
    }

    @Test func preservesRawHoursAndExplainsConservativeSafetyExpansion() throws {
        let forecast = fixture(levels: Array(repeating: .okay, count: 8) + [.avoid] + Array(repeating: .okay, count: 9))
        let result = try presentation(forecast)
        #expect(result.hours[7].recommendation.level == .okay)
        #expect(result.hours[8].recommendation.level == .avoid)
        #expect(result.periods.contains { $0.interval.start == result.hours[7].id && $0.recommendation.level == .avoid })
        #expect(result.hasConsolidatedDifferences)
        #expect(result.hours.map(\.id) == forecast.hours.map(\.timestamp))
    }

    @Test func heroDoesNotTurnBriefCautionIntoAnOptimisticDailyAnswer() throws {
        let result = try presentation(fixture(levels: Array(repeating: .okay, count: 8)
            + [.caution] + Array(repeating: .okay, count: 9)))
        #expect(result.summary?.level == .caution)
        #expect(result.summary?.reason == "It may feel too warm.")
        #expect(result.periods.count == 1)
        #expect(result.periods.first?.recommendation.level == .okay)
        #expect(result.hasConsolidatedDifferences)
    }

    @Test func preservesVariableNumbersOfPeriods() throws {
        for count in [1, 2, 4, 6] {
            let levels: [RecommendationLevel] = (0..<count).flatMap { index in
                Array(repeating: index.isMultiple(of: 2) ? .okay : .avoid,
                      count: 18 / count + (index == count - 1 ? 18 % count : 0))
            }
            let result = try presentation(fixture(levels: levels))
            #expect(result.periods.count == count)
            #expect(result.hours.count == 18)
            #expect(!result.hasConsolidatedDifferences)
        }
    }

    @Test func missingHourIsMarkedUncertainEvenWhenGroupingAbsorbsIt() throws {
        let original = fixture()
        var hours = original.hours
        let missing = hours.remove(at: 4).timestamp
        let result = try presentation(NormalizedForecast(hours: hours, metadata: original.metadata))
        #expect(result.hours[4].id == missing)
        #expect(result.hours[4].isInferred)
        #expect(result.hours[4].accessibilityLabel.contains("forecast uncertain"))
        #expect(result.hasInferredHour)
        #expect(result.summary?.level == .caution)
        #expect(result.summary?.recommendation.reason == .incompleteForecast)
        #expect(result.hasConsolidatedDifferences)
        #expect(result.periods.count == 1) // Existing short-change absorption remains intact.

        hours.remove(at: 6)
        #expect(engine.evaluateHours(NormalizedForecast(hours: hours, metadata: original.metadata), now: original.hours[0].timestamp) == nil)
        #expect(engine.evaluateHours(NormalizedForecast(hours: Array(original.hours.dropFirst()), metadata: original.metadata), now: original.hours[0].timestamp) == nil)
    }

    @Test func remainingDayTimelineUsesLocationTimeAndExcludesPastAndTomorrow() throws {
        let forecast = fixture()
        let now = forecast.hours[5].timestamp.addingTimeInterval(1_800)
        let evaluation = try #require(engine.evaluateHours(forecast, now: now))
        let result = makePresentation(evaluation)
        #expect(result.hours.count == 13)
        #expect(result.hours.first?.timeLabel == "11:00")
        #expect(result.hours.last?.timeLabel == "23:00")
        #expect(result.periods.first?.label == "11:00–00:00")
        #expect(result.summary?.level == .okay)
    }

    @Test func daylightSavingTimelineSkipsAndDisambiguatesLocalHours() throws {
        let zone = try #require(TimeZone(identifier: "Europe/Brussels"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        for (month, day, count) in [(3, 29, 23), (10, 25, 25)] {
            let start = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: day)))
            let forecast = NormalizedForecast(
                hours: (0..<count).map { hour(start.addingTimeInterval(Double($0) * 3_600)) },
                metadata: ForecastMetadata(fetchedAt: start, location: LocationIdentity(latitude: 50.85, longitude: 4.35))
            )
            let result = try presentation(forecast)
            #expect(result.hours.count == count)
            #expect(Set(result.hours.map(\.id)).count == count)
            #expect(result.hours.last?.timeLabel == "23:00")
            if count == 23 {
                #expect(!result.hours.contains { $0.timeLabel == "02:00" })
                #expect(!result.hasRepeatedLocalHour)
            } else {
                let repeated = result.hours.filter { $0.timeLabel == "02:00" }
                #expect(repeated.count == 2)
                #expect(repeated[0].unambiguousTimeLabel == "02:00 UTC+02:00")
                #expect(repeated[1].unambiguousTimeLabel == "02:00 UTC+01:00")
                #expect(result.hasRepeatedLocalHour)
                #expect(result.periods[0].label.contains("UTC+02:00"))
                #expect(result.periods[0].label.contains("UTC+01:00"))
            }
        }
    }

    private func presentation(_ forecast: NormalizedForecast) throws -> DailyRecommendationPresentation {
        makePresentation(try #require(engine.evaluateHours(forecast, now: forecast.hours[0].timestamp)))
    }

    private func makePresentation(_ evaluation: DailyEvaluation) -> DailyRecommendationPresentation {
        DailyRecommendationPresentation(
            periods: DayPeriodEngine().periods(for: evaluation).map {
                PeriodPresentation(interval: $0.interval, timezoneIdentifier: $0.timezoneIdentifier,
                                   recommendation: RecommendationPresentation(recommendation: $0.recommendation))
            },
            hours: evaluation.hours.map { HourlySuitabilityPresentation(hour: $0, timezoneIdentifier: evaluation.timezoneIdentifier) },
            weatherFetchedAt: evaluation.interval.start, isUsingSavedWeather: false, isRefreshing: false,
            refreshFailed: false, refreshAvailableAt: evaluation.interval.start
        )
    }

    private func fixture(levels: [RecommendationLevel] = Array(repeating: .okay, count: 18)) -> NormalizedForecast {
        let start = ISO8601DateFormatter().date(from: "2026-10-13T04:00:00Z")! // 06:00 Brussels
        return NormalizedForecast(
            hours: levels.enumerated().map { index, level in
                hour(start.addingTimeInterval(Double(index) * 3_600), temperature: level == .caution ? 18 : 12, amount: level == .avoid ? 1 : 0)
            },
            metadata: ForecastMetadata(fetchedAt: start, location: LocationIdentity(latitude: 50.85, longitude: 4.35))
        )
    }

    private func hour(_ timestamp: Date, temperature: Double = 12, amount: Double = 0, fog: FogOrMistCondition? = nil) -> HourlyWeather {
        HourlyWeather(timestamp: timestamp, timezoneIdentifier: "Europe/Brussels",
                      actualTemperatureCelsius: temperature, apparentTemperatureCelsius: temperature,
                      precipitationAmountMillimeters: amount, precipitationType: PrecipitationType.none,
                      precipitationChanceFraction: 0, fogOrMistCondition: fog)
    }
}
