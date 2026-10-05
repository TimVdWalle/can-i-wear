import Foundation
import Testing
@testable import Can_I_Wear

struct DailyRecommendationEngineTests {
    private let engine = DailyRecommendationEngine()
    private let now = Date(timeIntervalSince1970: 1_791_203_400) // 2026-10-05 14:30 local
    private let currentHour = Date(timeIntervalSince1970: 1_791_201_600) // 2026-10-05 14:00 local

    @Test func evaluatesOnlyRemainingLocalDayAndReturnsMostProtectiveResult() throws {
        var hours = completeRemainingDay()
        hours.insert(hour(at: currentHour.addingTimeInterval(-3_600), amount: 5), at: 0)
        hours[3] = hour(at: hours[3].timestamp, chance: 0.10)
        hours[5] = hour(at: hours[5].timestamp, amount: 1)
        hours.append(hour(at: currentHour.addingTimeInterval(10 * 3_600), amount: 10))

        let recommendation = engine.evaluate(forecast(hours), now: now)

        #expect(recommendation == HourlyRecommendation(level: .avoid, reason: .precipitation))
    }

    @Test func ignoresPastAndNextDayAvoidConditions() {
        var hours = completeRemainingDay()
        hours.insert(hour(at: currentHour.addingTimeInterval(-3_600), amount: 5), at: 0)
        hours.append(hour(at: currentHour.addingTimeInterval(10 * 3_600), amount: 5))

        #expect(engine.evaluate(forecast(hours), now: now)?.level == .okay)
    }

    @Test func returnsCautionWhenItIsTheMostProtectiveWeatherResult() {
        var hours = completeRemainingDay()
        hours[4] = hour(at: hours[4].timestamp, chance: 0.10)

        #expect(engine.evaluate(forecast(hours), now: now) == HourlyRecommendation(
            level: .caution,
            reason: .precipitationRisk
        ))
    }

    @Test func summarizesAllDayHeatAndImmediateRain() {
        let hotHours = completeRemainingDay().map {
            hour(at: $0.timestamp, actual: 24, apparent: 24)
        }
        var immediateRain = completeRemainingDay()
        immediateRain[0] = hour(at: immediateRain[0].timestamp, amount: 1)

        #expect(engine.evaluate(forecast(hotHours), now: now) == HourlyRecommendation(
            level: .avoid,
            reason: .excessiveHeat
        ))
        #expect(engine.evaluate(forecast(immediateRain), now: now) == HourlyRecommendation(
            level: .avoid,
            reason: .precipitation
        ))
    }

    @Test func infersOneBracketedGapAsAtLeastCaution() {
        var hours = completeRemainingDay()
        hours.remove(at: 4)

        #expect(engine.evaluate(forecast(hours), now: now) == HourlyRecommendation(
            level: .caution,
            reason: .incompleteForecast
        ))
    }

    @Test func preservesAvoidFromNeighboringHourAcrossOneGap() {
        var hours = completeRemainingDay()
        hours[3] = hour(at: hours[3].timestamp, amount: 1)
        hours.remove(at: 4)

        #expect(engine.evaluate(forecast(hours), now: now)?.level == .avoid)
    }

    @Test func rejectsMultipleOrEdgeGaps() {
        var multipleGaps = completeRemainingDay()
        multipleGaps.remove(at: 4)
        multipleGaps.remove(at: 2)

        var firstHourGap = completeRemainingDay()
        firstHourGap.removeFirst()

        var lastHourGap = completeRemainingDay()
        lastHourGap.removeLast()

        #expect(engine.evaluate(forecast(multipleGaps), now: now) == nil)
        #expect(engine.evaluate(forecast(firstHourGap), now: now) == nil)
        #expect(engine.evaluate(forecast(lastHourGap), now: now) == nil)
    }

    @Test func treatsAnUnusableHourAsAGap() {
        var hours = completeRemainingDay()
        hours[4] = hour(at: hours[4].timestamp, actual: nil, apparent: nil)

        #expect(engine.evaluate(forecast(hours), now: now)?.level == .caution)
    }

    @Test func rejectsMissingTimezoneAndDuplicateHours() {
        var missingTimezone = completeRemainingDay()
        missingTimezone = missingTimezone.map {
            hour(at: $0.timestamp, timezoneIdentifier: nil)
        }

        var duplicate = completeRemainingDay()
        duplicate.append(duplicate[2])

        #expect(engine.evaluate(forecast(missingTimezone), now: now) == nil)
        #expect(engine.evaluate(forecast(duplicate), now: now) == nil)
    }

    private func completeRemainingDay() -> [HourlyWeather] {
        (0..<10).map { offset in
            hour(at: currentHour.addingTimeInterval(TimeInterval(offset * 3_600)))
        }
    }

    private func forecast(_ hours: [HourlyWeather]) -> NormalizedForecast {
        NormalizedForecast(
            hours: hours,
            metadata: ForecastMetadata(
                fetchedAt: now,
                location: LocationIdentity(latitude: 50.85, longitude: 4.35)
            )
        )
    }

    private func hour(
        at timestamp: Date,
        timezoneIdentifier: String? = "Europe/Brussels",
        actual: Double? = 12,
        apparent: Double? = 12,
        amount: Double? = 0,
        chance: Double? = 0
    ) -> HourlyWeather {
        HourlyWeather(
            timestamp: timestamp,
            timezoneIdentifier: timezoneIdentifier,
            actualTemperatureCelsius: actual,
            apparentTemperatureCelsius: apparent,
            precipitationAmountMillimeters: amount,
            precipitationType: PrecipitationType.none,
            precipitationChanceFraction: chance
        )
    }
}
