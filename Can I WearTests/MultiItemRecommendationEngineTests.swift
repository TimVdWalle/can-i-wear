import Foundation
import Testing
@testable import Can_I_Wear

struct MultiItemRecommendationEngineTests {
    private let engine = MultiItemRecommendationEngine()
    private let usefulnessItems = PredefinedItem.allCases.filter { $0 != .leatherJacket }

    @Test(arguments: PredefinedItem.allCases)
    func approvedDailyMatrixAppliesToEveryAssignedItem(item: PredefinedItem) throws {
        let cases: [([ItemAdviceLevel], ItemDailyVerdict, ItemDailyVerdict)] = [
            ([.yes, .yes, .yes], .goodForRemainingDay, .useful),
            ([.yes, .no, .yes], .restricted, .useful),
            ([.no, .no, .yes, .no], .restricted, .brieflyUseful),
            ([.no, .yes, .no, .yes], .restricted, .useful),
            ([.no, .yes, .yes, .no], .restricted, .useful),
            ([.yes, .maybe, .no], .restricted, .brieflyUseful),
            ([.yes, .maybe, .yes], .caution, .useful),
            ([.no, .maybe, .no], .restricted, .maybeUseful),
            ([.maybe, .maybe, .maybe], .caution, .maybeUseful),
            ([.no, .no, .no], .restricted, .notNeeded),
            ([.yes], .goodForRemainingDay, .brieflyUseful)
        ]
        for (levels, jacketVerdict, usefulnessVerdict) in cases {
            let forecast = ItemEngineFixtures.sequence(levels, for: item)
            let start = try #require(forecast.hours.first?.timestamp)
            let result = try #require(engine.evaluate(forecast, for: item, now: start.addingTimeInterval(1_800)))
            #expect(result.verdict == (item == .leatherJacket ? jacketVerdict : usefulnessVerdict))
            #expect(result.hours.map(\.advice.level) == levels)
            #expect(result.interval == DateInterval(start: start, end: ItemEngineFixtures.dayEnd))
            #expect(result.qualifyingHours.count == levels.filter { $0 == .yes }.count)
            #expect(!result.reasons.isEmpty)
            #expect(result.periods.first?.interval.start == start)
            #expect(result.periods.last?.interval.end == ItemEngineFixtures.dayEnd)
            if item != .leatherJacket {
                let usefulPeriodHours = result.periods.filter { $0.level == .yes }
                    .reduce(0.0) { $0 + $1.interval.duration / 3_600 }
                #expect(usefulPeriodHours == Double(result.qualifyingHours.count))
            }
        }
    }

    @Test func singleIsolatedGapIsUncertainAndNeverCountedForUsefulness() throws {
        for item in usefulnessItems {
            let cases: [([ItemAdviceLevel], ItemDailyVerdict, Int)] = [
                ([.no, .yes, .no], .maybeUseful, 0),
                ([.yes, .yes, .no], .brieflyUseful, 1),
                ([.yes, .no, .yes], .useful, 2)
            ]
            for (levels, expected, count) in cases {
                var forecast = ItemEngineFixtures.sequence(levels, for: item)
                let start = forecast.hours[0].timestamp
                let gapTimestamp = forecast.hours[1].timestamp
                forecast = ItemEngineFixtures.forecast([forecast.hours[0], forecast.hours[2]])
                let result = try #require(engine.evaluate(forecast, for: item, now: start))
                #expect(result.verdict == expected)
                #expect(result.qualifyingHours.count == count)
                #expect(result.hours[1].timestamp == gapTimestamp)
                #expect(result.hours[1].advice == ItemHourlyAdvice(level: .maybe, reason: .incompleteForecast))
                #expect(result.hours[1].isInferred)
                #expect(result.periods.contains { $0.isInferred && $0.interval.duration == 3_600 })
            }
        }
    }

    @Test func missingRequiredSignalsUseTheSameGapRuleAsMissingRows() throws {
        for item in usefulnessItems {
            let complete = ItemEngineFixtures.sequence([.yes, .yes, .yes], for: item)
            var hours = complete.hours
            hours[1] = ItemEngineFixtures.hour(
                at: hours[1].timestamp, actual: nil, amount: nil, chance: nil, daylight: nil, sky: nil, uv: 9
            )
            let result = try #require(engine.evaluate(ItemEngineFixtures.forecast(hours), for: item, now: hours[0].timestamp))
            #expect(result.verdict == .useful)
            #expect(result.qualifyingHours.count == 2)
            #expect(result.hours[1].isInferred)
        }
    }

    @Test func edgeOrMultipleGapsRejectTheDayEvenWithTwoKnownUsefulHours() {
        for item in PredefinedItem.allCases {
            let complete = ItemEngineFixtures.sequence([.yes, .yes, .yes, .yes, .yes], for: item)
            let start = complete.hours[0].timestamp
            for indices in [[0], [4], [1, 3]] {
                let partial = ItemEngineFixtures.forecast(complete.hours.enumerated().compactMap { index, hour in
                    indices.contains(index) ? nil : hour
                })
                #expect(engine.evaluate(partial, for: item, now: start) == nil)
            }
        }
    }

    @Test func contiguousGroupingKeepsShortChangesAndDoesNotApplyJacketSmoothing() throws {
        let sequences: [[ItemAdviceLevel]] = [
            [.yes, .yes, .yes], [.yes, .yes, .no, .yes], [.yes, .no, .yes],
            [.no, .yes, .no], [.maybe, .maybe, .no], [.yes, .no, .yes, .no, .yes]
        ]
        for item in usefulnessItems {
            for levels in sequences {
                let forecast = ItemEngineFixtures.sequence(levels, for: item)
                let result = try #require(engine.evaluate(forecast, for: item, now: forecast.hours[0].timestamp))
                let expanded = result.periods.flatMap { period in
                    Array(repeating: period.level, count: Int(period.interval.duration / 3_600))
                }
                #expect(expanded == levels)
                for (previous, next) in zip(result.periods, result.periods.dropFirst()) {
                    #expect(previous.interval.end == next.interval.start)
                    #expect(previous.level != next.level)
                }
            }
        }
    }

    @Test func inferredMaybeDoesNotDisappearIntoObservedBorderlinePeriods() throws {
        let original = ItemEngineFixtures.sequence([.maybe, .maybe, .maybe], for: .sunglasses)
        let partial = ItemEngineFixtures.forecast([original.hours[0], original.hours[2]])
        let result = try #require(engine.evaluate(partial, for: .sunglasses, now: original.hours[0].timestamp))
        #expect(result.verdict == .maybeUseful)
        #expect(result.periods.map(\.isInferred) == [false, true, false])
        #expect(result.reasons == [.partlyCloudy, .incompleteForecast])
    }

    @Test func equalLevelPeriodsRetainTheirDifferentWeatherReasons() throws {
        let start = ItemEngineFixtures.dayEnd.addingTimeInterval(-2 * 3_600)
        let forecast = ItemEngineFixtures.forecast([
            ItemEngineFixtures.hour(at: start, amount: 0.1, wind: 30),
            ItemEngineFixtures.hour(at: start.addingTimeInterval(3_600), amount: 0.5)
        ])
        let result = try #require(engine.evaluate(forecast, for: .raincoat, now: start))
        #expect(result.periods.count == 1)
        #expect(result.periods[0].reasons == [.windDrivenPrecipitation, .precipitation])
        #expect(result.reasons == [.windDrivenPrecipitation, .precipitation])
        #expect(result.hours.map(\.advice.reason) == [.windDrivenPrecipitation, .precipitation])
    }

    @Test func jacketSummaryAndSafetyPeriodsMatchOriginalEngines() throws {
        let cases: [[ItemAdviceLevel]] = [
            [.yes, .yes, .yes, .yes], [.yes, .no, .yes, .yes],
            [.no, .yes, .no, .yes], [.yes, .maybe, .yes, .yes]
        ]
        for levels in cases {
            let forecast = ItemEngineFixtures.sequence(levels, for: .leatherJacket)
            let now = forecast.hours[0].timestamp
            let original = try #require(DailyRecommendationEngine().evaluateHours(forecast, now: now))
            let result = try #require(engine.evaluate(forecast, for: .leatherJacket, now: now))
            #expect(result.hours.map(\.advice) == original.hours.map { ItemHourlyAdvice(jacket: $0.recommendation) })
            let periods = DayPeriodEngine().periods(for: original)
            #expect(result.periods.map(\.interval) == periods.map(\.interval))
            #expect(result.periods.map(\.level) == periods.map { ItemHourlyAdvice(jacket: $0.recommendation).level })
            #expect(result.reasons == [ItemHourlyAdvice(jacket: try #require(
                HourlyRecommendation.mostProtective(in: original.hours.map(\.recommendation))
            )).reason])
        }
        var hours = ItemEngineFixtures.sequence([.yes, .yes, .yes, .yes], for: .leatherJacket).hours
        hours[1] = ItemEngineFixtures.hour(at: hours[1].timestamp, actual: 30, fog: .fog)
        hours[2] = ItemEngineFixtures.hour(at: hours[2].timestamp, amount: 1)
        let result = try #require(engine.evaluate(ItemEngineFixtures.forecast(hours), for: .leatherJacket, now: hours[0].timestamp))
        #expect(result.reasons == [.jacket(.precipitation)])
    }

    @Test func jacketInferredHourStaysProtectiveWhileUsefulnessInferenceStaysMaybe() throws {
        let original = ItemEngineFixtures.sequence([.no, .yes, .yes], for: .leatherJacket)
        let partial = ItemEngineFixtures.forecast([original.hours[0], original.hours[2]])
        let result = try #require(engine.evaluate(partial, for: .leatherJacket, now: original.hours[0].timestamp))
        #expect(result.verdict == .restricted)
        #expect(result.hours[1].advice.level == .no)
        #expect(result.hours[1].isInferred)
        #expect(result.qualifyingHours.count == 1)

        let safe = ItemEngineFixtures.sequence([.yes, .yes, .yes], for: .leatherJacket)
        let safePartial = ItemEngineFixtures.forecast([safe.hours[0], safe.hours[2]])
        let uncertain = try #require(engine.evaluate(safePartial, for: .leatherJacket, now: safe.hours[0].timestamp))
        #expect(uncertain.verdict == .caution)
        #expect(uncertain.reasons == [.incompleteForecast])
    }

    @Test func eachItemRemainsIndependentlyAvailableFromOneForecast() throws {
        let start = ItemEngineFixtures.dayEnd.addingTimeInterval(-2 * 3_600)
        let forecast = ItemEngineFixtures.forecast((0..<2).map {
            ItemEngineFixtures.hour(at: start.addingTimeInterval(Double($0) * 3_600), actual: 5, sky: nil)
        })
        let results = engine.evaluate(forecast, now: start)
        #expect(results.map(\.item) == PredefinedItem.allCases)
        #expect(results.filter { $0.evaluation == nil }.map(\.item) == [.sunglasses])
        #expect(results.first { $0.item == .leatherJacket }?.evaluation?.verdict == .goodForRemainingDay)
        #expect(results.first { $0.item == .warmCoat }?.evaluation?.verdict == .useful)
        #expect(results.first { $0.item == .raincoat }?.evaluation?.verdict == .notNeeded)
        let selected = engine.evaluate(forecast, for: [.gloves, .sunglasses, .gloves], now: start)
        #expect(selected.map(\.item) == [.gloves, .sunglasses])
        #expect(engine.evaluate(forecast, for: [], now: start).isEmpty)
    }

    @Test func ignoresPastAndNextDayHoursAndOrdersTheRemainingWindow() throws {
        for item in usefulnessItems {
            let current = ItemEngineFixtures.sequence([.no, .no], for: item)
            let start = current.hours[0].timestamp
            var hours = current.hours
            hours.insert(ItemEngineFixtures.hour(for: item, level: .yes, at: start.addingTimeInterval(-3_600)), at: 0)
            hours.append(ItemEngineFixtures.hour(for: item, level: .yes, at: ItemEngineFixtures.dayEnd))
            let result = try #require(engine.evaluate(
                ItemEngineFixtures.forecast(Array(hours.reversed())), for: item, now: start.addingTimeInterval(1_800)
            ))
            #expect(result.verdict == .notNeeded)
            #expect(result.hours.map(\.timestamp) == current.hours.map(\.timestamp))
        }
    }

    @Test func rejectsDuplicateHoursAndAbsentInvalidOrConflictingTimezones() {
        let forecast = ItemEngineFixtures.sequence([.yes, .yes, .yes], for: .sunglasses)
        let start = forecast.hours[0].timestamp
        let duplicate = ItemEngineFixtures.forecast(forecast.hours + [forecast.hours[1]])
        let missing = ItemEngineFixtures.forecast(forecast.hours.map { ItemEngineFixtures.hour(at: $0.timestamp, timezone: nil) })
        let invalid = ItemEngineFixtures.forecast(forecast.hours.map { ItemEngineFixtures.hour(at: $0.timestamp, timezone: "invalid") })
        let conflicting = ItemEngineFixtures.forecast(forecast.hours + [ItemEngineFixtures.hour(
            at: ItemEngineFixtures.dayEnd, timezone: "Europe/Brussels"
        )])
        for input in [duplicate, missing, invalid, conflicting, ItemEngineFixtures.forecast([])] {
            #expect(engine.evaluate(input, for: .sunglasses, now: start) == nil)
        }
        var oneMissing = forecast.hours
        oneMissing[1] = ItemEngineFixtures.hour(at: oneMissing[1].timestamp, timezone: nil)
        #expect(engine.evaluate(ItemEngineFixtures.forecast(oneMissing), for: .sunglasses, now: start)?.hours[1].isInferred == true)
    }

    @Test func shortLongAndOffsetLocalDaysRetainActualUTCTimestamps() throws {
        for (month, day, timezone, count) in [
            (3, 29, "Europe/Brussels", 23), (10, 25, "Europe/Brussels", 25),
            (10, 20, "Asia/Kathmandu", 24)
        ] {
            let start = ItemEngineFixtures.date(year: 2026, month: month, day: day, timezone: timezone)
            let hours = (0..<count).map { offset in
                ItemEngineFixtures.hour(
                    at: start.addingTimeInterval(Double(offset) * 3_600), timezone: timezone, actual: 5
                )
            }
            for item in PredefinedItem.allCases {
                let result = try #require(engine.evaluate(ItemEngineFixtures.forecast(hours), for: item, now: start))
                #expect(result.hours.count == count)
                #expect(result.interval.duration == Double(count) * 3_600)
                #expect(result.timezoneIdentifier == timezone)
                #expect(result.hours.map(\.timestamp) == hours.map(\.timestamp))
                let later = try #require(engine.evaluate(
                    ItemEngineFixtures.forecast(hours), for: item, now: start.addingTimeInterval(3 * 3_600 + 1_800)
                ))
                #expect(later.hours.count == count - 3)
                #expect(later.interval.start == hours[3].timestamp)
            }
        }
    }
}
