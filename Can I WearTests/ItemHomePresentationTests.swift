import Foundation
import Testing
@testable import Can_I_Wear

struct ItemHomePresentationTests {
    @Test(arguments: PredefinedItem.allCases.filter { $0 != .leatherJacket })
    func daypartSummaryUsesAnyUsefulHourThenMaybeWithoutChangingDailyMinimum(item: PredefinedItem) throws {
        for (levels, expected) in [
            ([ItemAdviceLevel.no, .yes, .no, .no, .no, .no], ItemAdviceLevel.yes),
            ([.yes, .no, .yes, .no, .no, .no], .yes),
            ([.no, .maybe, .no, .no, .no, .no], .maybe),
            ([.maybe, .yes, .no, .maybe, .no, .no], .yes),
            (Array(repeating: .no, count: 6), .no)
        ] {
            let forecast = ItemEngineFixtures.sequence(levels + Array(repeating: .no, count: 12), for: item)
            let evaluation = try #require(MultiItemRecommendationEngine().evaluate(forecast, for: item, now: forecast.hours[0].timestamp))
            let parts = FixedDayPartPresentation.make(from: evaluation, at: forecast.hours[0].timestamp)
            #expect(parts[0].itemSummaryLevel == expected)
            #expect(parts[1].itemSummaryLevel == .no)
            #expect(parts[2].statusTitle == "NO")
            #expect(evaluation.qualifyingHours.count == levels.filter { $0 == .yes }.count)
            if levels.filter({ $0 == .yes }).count == 1 {
                #expect(parts[0].statusTitle == "YES")
                #expect(evaluation.verdict == .brieflyUseful)
            }
        }
    }

    @Test func missingCoverageNeverProducesConfidentDaypartNoAndInferredHoursNeverProduceYes() throws {
        let late = try #require(presentation([.no], item: .sunglasses).evaluation)
        let parts = FixedDayPartPresentation.make(from: late, at: late.interval.start)
        #expect(parts.allSatisfy { $0.itemSummaryLevel == nil && $0.statusTitle == "—" })
        let original = ItemEngineFixtures.sequence(Array(repeating: .no, count: 18), for: .sunglasses)
        let missing = ItemEngineFixtures.forecast(original.hours.enumerated().filter { $0.offset != 8 }.map(\.element))
        let evaluation = try #require(MultiItemRecommendationEngine().evaluate(missing, for: .sunglasses, now: original.hours[0].timestamp))
        let inferredParts = FixedDayPartPresentation.make(from: evaluation, at: original.hours[0].timestamp)
        #expect(inferredParts[1].itemSummaryLevel == .maybe)
        #expect(inferredParts[1].statusTitle == "MAYBE")
        #expect(inferredParts[1].accessibilityLabel.contains("Uncertain"))
        #expect(evaluation.qualifyingHours.isEmpty)
        var uncovered = inferredParts[1]
        uncovered.itemAdvicePeriods.removeAll(where: \.isInferred)
        #expect(uncovered.itemSummaryLevel == nil)
        #expect(uncovered.accessibilityLabel.contains("Unavailable"))
    }

    @Test(arguments: PredefinedItem.allCases.filter { $0 != .leatherJacket })
    func sharedTimelinePreservesRawAdviceReasonsPastHoursAndUncertainty(item: PredefinedItem) throws {
        let evaluation = try #require(presentation([.yes, .no, .maybe], item: item).evaluation)
        let now = evaluation.hours[1].timestamp
        let segments = evaluation.hours.map {
            HourlyTimelineSegment($0, item: item, timezone: evaluation.timezoneIdentifier, currentTime: now)
        }
        #expect(segments.map(\.id) == evaluation.hours.map(\.timestamp))
        #expect(segments.map(\.tone) == [.positive, .neutral, .caution])
        #expect(segments.map(\.isPast) == [true, false, false])
        #expect(segments[0].accessibilityLabel.contains("YES, Useful, finished for today"))
        #expect(segments[1].accessibilityLabel.contains("NO, Not needed"))
        #expect(segments[2].accessibilityLabel.contains(ItemHomePresentation.reasonText(evaluation.hours[2].advice.reason)))
        let uncertain = HourlyTimelineSegment(
            EvaluatedItemHour(timestamp: now, advice: ItemHourlyAdvice(level: .maybe, reason: .incompleteForecast)),
            item: item, timezone: "UTC", currentTime: nil
        )
        #expect(uncertain.isInferred)
        #expect(uncertain.tone == .caution)
        #expect(uncertain.accessibilityLabel.contains("Forecast uncertain"))
        #expect(!uncertain.accessibilityLabel.contains("YES"))
    }

    @Test func sharedJacketTimelineRetainsExistingLabelsAndLevels() {
        for (level, tone) in [(RecommendationLevel.okay, ItemAdviceTone.positive), (.caution, .caution), (.avoid, .negative)] {
            let original = HourlySuitabilityPresentation(
                hour: EvaluatedHour(timestamp: ItemEngineFixtures.dayEnd, recommendation: HourlyRecommendation(level: level, reason: .suitableTemperature)),
                timezoneIdentifier: "Europe/Brussels", isPast: true
            )
            let segment = HourlyTimelineSegment(original)
            #expect(segment.tone == tone)
            #expect(segment.accessibilityLabel == original.accessibilityLabel)
            #expect(segment.axisTimeLabel == original.axisTimeLabel)
            #expect(segment.unambiguousAxisTimeLabel == original.unambiguousAxisTimeLabel)
            #expect(segment.isPast)
        }
        let midnight = ItemEngineFixtures.date(year: 2026, month: 10, day: 25, timezone: "Europe/Brussels")
        let repeated = [2, 3].map { offset in
            HourlyTimelineSegment(
                EvaluatedItemHour(timestamp: midnight.addingTimeInterval(Double(offset) * 3_600), advice: ItemHourlyAdvice(level: .no, reason: .night)),
                item: .sunglasses, timezone: "Europe/Brussels", currentTime: nil
            )
        }
        #expect(repeated[0].timeLabel == repeated[1].timeLabel)
        #expect(repeated[0].unambiguousAxisTimeLabel != repeated[1].unambiguousAxisTimeLabel)
    }

    @Test(arguments: PredefinedItem.allCases.filter { $0 != .leatherJacket })
    func everyUsefulnessItemKeepsThreeNamedCardsAndExactAdviceInsideThem(item: PredefinedItem) throws {
        let levels = Array(repeating: ItemAdviceLevel.no, count: 6)
            + [.yes, .no, .yes, .maybe, .no, .no] + Array(repeating: .no, count: 6)
        let forecast = ItemEngineFixtures.sequence(levels, for: item)
        let start = forecast.hours[0].timestamp
        let evaluation = try #require(MultiItemRecommendationEngine().evaluate(forecast, for: item, now: start))
        let parts = FixedDayPartPresentation.make(from: evaluation, at: start.addingTimeInterval(17.5 * 3_600))
        #expect(parts.map(\.dayPart) == [.morning, .afternoon, .evening])
        #expect(parts.map(\.timeRangeLabel) == ["06–12", "12–18", "18–24"])
        #expect(parts.map(\.isPast) == [true, true, false])
        #expect(parts[1].itemAdvicePeriods.map(\.level) == [.yes, .no, .yes, .maybe, .no])
        #expect(parts[1].itemAdvicePeriods[0].interval.duration == 3_600)
        #expect(parts[1].accessibilityLabel.contains("12:00–13:00, Useful"))
        #expect(parts[1].accessibilityLabel.contains("14:00–15:00, Useful"))
        #expect(parts[1].accessibilityLabel.contains("15:00–16:00, Maybe useful"))
        #expect(evaluation.verdict == .useful)
        #expect(evaluation.qualifyingHours.count == 2)
        let displayedDuration: TimeInterval = parts.flatMap(\.itemAdvicePeriods).reduce(0) { $0 + $1.interval.duration }
        #expect(displayedDuration == 18 * 3_600)
    }

    @Test func oneEveningUsefulHourIsNotExpandedToTheWholeEvening() throws {
        let forecast = ItemEngineFixtures.sequence(
            Array(repeating: ItemAdviceLevel.no, count: 12) + [.yes] + Array(repeating: .no, count: 5), for: .sunglasses
        )
        let evaluation = try #require(MultiItemRecommendationEngine().evaluate(forecast, for: .sunglasses, now: forecast.hours[0].timestamp))
        let parts = FixedDayPartPresentation.make(from: evaluation, at: forecast.hours[17].timestamp)
        #expect(parts.count == 3)
        #expect(parts[2].itemAdvicePeriods.map(\.level) == [.yes, .no])
        #expect(parts[2].statusTitle == "YES")
        #expect(parts[2].accessibilityLabel.contains("18:00–19:00, Useful"))
        #expect(parts[2].accessibilityLabel.contains("19:00–24:00, Not needed"))
        #expect(evaluation.verdict == .brieflyUseful)
    }

    @Test func missingPastContextStaysUnavailableAndInferredAdviceRemainsUncertain() throws {
        let late = try presentation([.no], item: .sunglasses)
        let evaluation = try #require(late.evaluation)
        let parts = FixedDayPartPresentation.make(from: evaluation, at: evaluation.interval.start)
        #expect(parts.count == 3)
        #expect(parts[0].accessibilityLabel.contains("Unavailable"))
        #expect(parts[1].accessibilityLabel.contains("Unavailable"))
        #expect(parts[2].accessibilityLabel.contains("23:00–24:00, Not needed"))
        let original = ItemEngineFixtures.sequence(Array(repeating: .yes, count: 18), for: .sunglasses)
        let forecast = ItemEngineFixtures.forecast(original.hours.enumerated().filter { $0.offset != 8 }.map(\.element))
        let inferred = try #require(MultiItemRecommendationEngine().evaluate(forecast, for: .sunglasses, now: original.hours[0].timestamp))
        let uncertain = FixedDayPartPresentation.make(from: inferred, at: original.hours[0].timestamp)
        #expect(uncertain[1].itemAdvicePeriods.contains { $0.isInferred })
        #expect(uncertain[1].accessibilityLabel.contains("14:00–15:00, Uncertain"))
    }

    @Test func usefulnessTitlesAndActualTimesDistinguishBriefSeparateBorderlineAndNoNeed() throws {
        let brief = try presentation([.no, .yes, .no], item: .sunglasses)
        #expect(brief.title == "Briefly useful")
        #expect(brief.timing == "22:00–23:00")
        #expect(brief.tone == .caution)
        let separate = try presentation([.yes, .no, .yes, .no], item: .sunglasses)
        #expect(separate.title == "Useful today")
        #expect(separate.timing == "20:00–21:00 · 22:00–23:00")
        #expect(try presentation([.no, .maybe, .no], item: .raincoat).title == "May be useful")
        let notNeeded = try presentation([.no, .no], item: .raincoat)
        #expect(notNeeded.title == "Not needed today")
        #expect(notNeeded.tone == .neutral)
        #expect(notNeeded.reason == "Dry forecast.")
        #expect(notNeeded.timing == "22:00–24:00")
    }

    @Test func uncertaintyRemainsExposedEvenWithEnoughUsefulHours() throws {
        let original = ItemEngineFixtures.sequence([.yes, .yes, .yes], for: .sunglasses)
        let partial = ItemEngineFixtures.forecast([original.hours[0], original.hours[2]])
        let result = try #require(MultiItemRecommendationEngine().evaluate(partial, for: .sunglasses, now: original.hours[0].timestamp))
        let display = ItemHomePresentation(result: ItemForecastResult(item: .sunglasses, evaluation: result))
        #expect(display.title == "Useful today")
        #expect(display.accessibilityLabel.contains("One forecast hour is uncertain"))
        #expect(display.evaluation?.periods[1].isInferred == true)
        let noUse = ItemEngineFixtures.sequence([.no, .yes, .no], for: .sunglasses)
        let uncertain = ItemEngineFixtures.forecast([noUse.hours[0], noUse.hours[2]])
        let evaluation = try #require(MultiItemRecommendationEngine().evaluate(uncertain, for: .sunglasses, now: noUse.hours[0].timestamp))
        #expect(ItemHomePresentation(result: ItemForecastResult(item: .sunglasses, evaluation: evaluation)).title == "Forecast uncertain")
    }

    @Test func unavailableIsNotNotNeededAndCannotInventTiming() {
        let result = ItemHomePresentation(result: ItemForecastResult(item: .sunglasses, evaluation: nil))
        #expect(result.title == "Not enough forecast data")
        #expect(result.tone == .neutral)
        #expect(result.reason == "Cannot assess the remaining day.")
        #expect(!result.timing.contains(":"))
        #expect(!result.accessibilityLabel.contains("Not needed"))
    }

    @Test func jacketTimingUsesSafetyPeriodsAndNeverHidesRawCaution() throws {
        let restricted = try presentation([.yes, .yes, .yes, .no, .yes, .yes, .yes], item: .leatherJacket)
        #expect(restricted.title == "Avoid during wet weather")
        #expect(restricted.timing == "19:00–21:00") // Includes the expanded preceding hour.
        let caution = try presentation([.yes, .maybe, .yes, .yes], item: .leatherJacket)
        #expect(caution.title == "Wear with caution")
        #expect(caution.timing == "21:00–22:00")
        #expect(caution.reason == "Precipitation is possible today.")
        #expect(try presentation([.yes, .yes], item: .leatherJacket).title == "Good for the rest of today")
    }

    @Test func jacketMixedRestrictionsKeepTheirMeaningAndPrimaryReason() throws {
        let start = ItemEngineFixtures.dayEnd.addingTimeInterval(-4 * 3_600)
        let hours = [
            ItemEngineFixtures.hour(at: start, actual: 24),
            ItemEngineFixtures.hour(at: start.addingTimeInterval(3_600), fog: .fog),
            ItemEngineFixtures.hour(at: start.addingTimeInterval(2 * 3_600), amount: 1),
            ItemEngineFixtures.hour(at: start.addingTimeInterval(3 * 3_600))
        ]
        let evaluation = try #require(MultiItemRecommendationEngine().evaluate(ItemEngineFixtures.forecast(hours), for: .leatherJacket, now: start))
        let display = ItemHomePresentation(result: ItemForecastResult(item: .leatherJacket, evaluation: evaluation))
        #expect(display.title == "Avoid at these times")
        #expect(display.reason.hasPrefix("Wet weather"))
        #expect(display.reason.contains("Too warm"))
        #expect(display.reason.contains("Fog"))
    }

    @Test func temperatureReasonIsCompactAndDoesNotMislabelActualFallbackAsFeelsLike() throws {
        let start = ItemEngineFixtures.dayEnd.addingTimeInterval(-2 * 3_600)
        let forecast = ItemEngineFixtures.forecast([
            ItemEngineFixtures.hour(at: start, actual: 3),
            ItemEngineFixtures.hour(at: start.addingTimeInterval(3_600), actual: 5)
        ])
        let result = try #require(MultiItemRecommendationEngine().evaluate(forecast, for: .gloves, now: start))
        let display = ItemHomePresentation(result: ItemForecastResult(item: .gloves, evaluation: result))
        #expect(display.reason == "Temperature: 3–5°C.")
        #expect(try presentation([.yes, .yes], item: .gloves).reason == "Temperature: 5°C.")
    }

    @Test func timingRetainsBothAbsorbedAndVisibleJacketCautionRanges() throws {
        let display = try presentation([
            .yes, .yes, .yes, .maybe, .maybe, .yes, .yes, .yes,
            .maybe, .maybe, .maybe, .yes, .yes, .yes
        ], item: .leatherJacket)
        #expect(display.title == "Wear with caution")
        #expect(display.timing == "13:00–15:00 · 18:00–21:00")
    }

    @Test func repeatedLocalHourRangeShowsBothUTCOffsets() {
        let midnight = ItemEngineFixtures.date(year: 2026, month: 10, day: 25, timezone: "Europe/Brussels")
        let repeated = DateInterval(start: midnight.addingTimeInterval(2 * 3_600), duration: 3_600)
        let range = ItemHomePresentation.range(repeated, timezone: "Europe/Brussels")
        #expect(range.contains("02:00 UTC+02:00"))
        #expect(range.contains("02:00 UTC+01:00"))
    }

    @Test func catalogAndHourlySemanticsNeverTreatNotNeededAsDanger() {
        for item in PredefinedItem.allCases {
            #expect(!item.name.isEmpty)
            #expect(!item.symbolName.isEmpty)
            #expect(item.id == item)
            #expect(ItemHomePresentation.tone(.no, item: item) == (item == .leatherJacket ? .negative : .neutral))
            #expect(ItemHomePresentation.levelTitle(.no, item: item) == (item == .leatherJacket ? "Avoid" : "Not needed"))
            #expect(ItemHomePresentation.levelTitle(.maybe, item: item, inferred: true) == "Uncertain")
        }
    }

    @Test func shortHeroAnswersPreserveDailyMeaningsAndUniformAdviceNeedsNoQualifier() throws {
        for (levels, item, title) in [
            ([ItemAdviceLevel.yes, .yes], PredefinedItem.leatherJacket, "YES"),
            ([.maybe, .maybe], .leatherJacket, "MAYBE"),
            ([.no, .no], .leatherJacket, "NO"),
            ([.yes, .yes], .sunglasses, "YES"),
            ([.maybe, .maybe], .raincoat, "MAYBE"),
            ([.no, .no], .raincoat, "NO")
        ] {
            let display = try presentation(levels, item: item)
            #expect(display.heroTitle == title)
            #expect(display.heroQualifier(dayParts: []) == nil)
            #expect(display.heroAccessibilityLabel(qualifier: nil).contains(display.title))
        }
        let unavailable = ItemHomePresentation(result: ItemForecastResult(item: .sunglasses, evaluation: nil))
        #expect(unavailable.heroTitle == nil)
        #expect(unavailable.heroQualifier(dayParts: []) == nil)
        #expect(!unavailable.heroAccessibilityLabel(qualifier: nil).contains("NO"))
        let brief = try presentation([.no, .yes, .no], item: .sunglasses)
        #expect(brief.heroTitle == "MAYBE")
        #expect(brief.heroQualifier(dayParts: []) == "Briefly useful · 22:00–23:00")
    }

    @Test func qualifierHighlightsLateEveningExceptionNotTheWholeSchedule() throws {
        let levels = Array(repeating: ItemAdviceLevel.yes, count: 6)
            + Array(repeating: .no, count: 10) + [.yes, .yes]
        let (late, parts) = try jacketHome(levels, currentHourOffset: 16)
        #expect(parts.last?.recommendation?.title == "NO")
        #expect(late.heroTitle == "YES")
        #expect(late.heroQualifier(dayParts: parts) == "Suitable 22:00–24:00")
        let (uniform, uniformParts) = try jacketHome(Array(repeating: .yes, count: 18))
        #expect(uniform.heroQualifier(dayParts: uniformParts) == nil)
        let (matching, matchingParts) = try jacketHome(
            Array(repeating: .yes, count: 6) + Array(repeating: .no, count: 12)
        )
        #expect(matching.heroQualifier(dayParts: matchingParts) == nil)
    }

    @Test func qualifierNeverCallsRawGreenBlipInsideProtectiveAvoidanceSuitable() throws {
        var levels = Array(repeating: ItemAdviceLevel.no, count: 18)
        levels[7] = .yes
        let (display, parts) = try jacketHome(levels)
        #expect(display.evaluation?.hours[7].advice.level == .yes)
        #expect(display.evaluation?.periods.allSatisfy { $0.level == .no } == true)
        #expect(display.heroQualifier(dayParts: parts) == nil)
    }

    @Test func qualifierRetainsAbsorbedCautionAndAvoidsListingSeveralExceptions() throws {
        var levels = Array(repeating: ItemAdviceLevel.yes, count: 18)
        levels[7] = .maybe
        let (display, parts) = try jacketHome(levels)
        #expect(display.heroTitle == "MAYBE")
        #expect(display.heroQualifier(dayParts: parts) == "Advice changes within dayparts.")
        // Only the final caution remains; earlier risk made the whole Evening card NO.
        let (caution, cautionParts) = try jacketHome(
            Array(repeating: .no, count: 14) + Array(repeating: .maybe, count: 4), currentHourOffset: 14
        )
        #expect(caution.heroQualifier(dayParts: cautionParts) == "Caution 20:00–24:00")
    }

    @Test func qualifierIncludesProtectiveExpansionAcrossDaypartBoundary() throws {
        var levels = Array(repeating: ItemAdviceLevel.yes, count: 18)
        levels[6] = .no
        let (display, parts) = try jacketHome(levels)
        // An unavailable Afternoon/Evening is not compared against a fabricated status.
        let unavailable = parts.dropFirst().map {
            FixedDayPartPresentation(dayPart: $0.dayPart, interval: $0.interval, recommendation: nil, isPast: false)
        }
        #expect(display.heroQualifier(dayParts: [parts[0]] + unavailable) == "Avoid 11:00–12:00")
    }

    @Test func earlyRestrictionExplainsNoWhenEveryDisplayedDaypartIsYes() throws {
        let (display, parts) = try jacketHome(
            Array(repeating: .no, count: 6) + Array(repeating: .yes, count: 18)
        )
        #expect(display.heroTitle == "NO")
        #expect(parts.allSatisfy { $0.recommendation?.title == "YES" })
        #expect(display.heroQualifier(dayParts: parts) == "Avoid 00:00–06:00")
        let (uniform, uniformParts) = try jacketHome(Array(repeating: .yes, count: 24))
        #expect(uniform.heroQualifier(dayParts: uniformParts) == nil)
    }

    private func jacketHome(
        _ levels: [ItemAdviceLevel], currentHourOffset: Int = 0
    ) throws -> (ItemHomePresentation, [FixedDayPartPresentation]) {
        let forecast = ItemEngineFixtures.sequence(levels, for: .leatherJacket)
        let start = try #require(forecast.hours.first?.timestamp)
        let now = start.addingTimeInterval(Double(currentHourOffset) * 3_600)
        let planning = try #require(DailyRecommendationEngine().evaluateHours(forecast, now: start))
        let remaining = try #require(MultiItemRecommendationEngine().evaluate(forecast, for: .leatherJacket, now: now))
        return (ItemHomePresentation(result: ItemForecastResult(item: .leatherJacket, evaluation: remaining)),
                FixedDayPartPresentation.make(from: planning, at: now))
    }

    private func presentation(_ levels: [ItemAdviceLevel], item: PredefinedItem) throws -> ItemHomePresentation {
        let forecast = ItemEngineFixtures.sequence(levels, for: item)
        let evaluation = try #require(MultiItemRecommendationEngine().evaluate(forecast, for: item, now: forecast.hours[0].timestamp))
        return ItemHomePresentation(result: ItemForecastResult(item: item, evaluation: evaluation))
    }
}
