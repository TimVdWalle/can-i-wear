import Foundation
import Testing
@testable import Can_I_Wear

struct ItemHomePresentationTests {
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

    private func presentation(_ levels: [ItemAdviceLevel], item: PredefinedItem) throws -> ItemHomePresentation {
        let forecast = ItemEngineFixtures.sequence(levels, for: item)
        let evaluation = try #require(MultiItemRecommendationEngine().evaluate(forecast, for: item, now: forecast.hours[0].timestamp))
        return ItemHomePresentation(result: ItemForecastResult(item: item, evaluation: evaluation))
    }
}
