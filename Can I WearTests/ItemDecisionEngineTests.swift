import Foundation
import Testing
@testable import Can_I_Wear

struct ItemDecisionEngineTests {
    private let engine = ItemDecisionEngine()
    private let temperatureItems: [PredefinedItem] = [.warmCoat, .sweater, .gloves, .shorts]

    @Test func catalogHasExactlyTheApprovedAssignments() {
        #expect(PredefinedItem.allCases.count == 7)
        #expect(PredefinedItem.leatherJacket.dailyPolicy == .canIWear)
        for item in PredefinedItem.allCases where item != .leatherJacket {
            #expect(item.dailyPolicy == .shouldIWear)
            #expect(PredefinedItem(rawValue: item.rawValue) == item)
        }
    }

    @Test func classifiesEveryTemperatureBoundary() {
        let cases: [(PredefinedItem, Double, ItemAdviceLevel)] = [
            (.warmCoat, -10, .yes), (.warmCoat, 5, .yes), (.warmCoat, 5.01, .maybe),
            (.warmCoat, 12, .maybe), (.warmCoat, 12.01, .no),
            (.sweater, 12, .yes), (.sweater, 12.01, .maybe), (.sweater, 18, .maybe), (.sweater, 18.01, .no),
            (.gloves, 5, .yes), (.gloves, 5.01, .maybe), (.gloves, 10, .maybe), (.gloves, 10.01, .no),
            (.shorts, 16.99, .no), (.shorts, 17, .maybe), (.shorts, 21.99, .maybe), (.shorts, 22, .yes)
        ]
        for (item, temperature, expected) in cases {
            let result = engine.evaluate(ItemEngineFixtures.hour(actual: temperature), for: item)
            #expect(result?.level == expected)
            #expect(result?.reason == .temperature(celsius: temperature))
        }
    }

    @Test func temperatureItemsPreferApparentWithActualOnlyFallback() {
        for item in temperatureItems {
            let apparent = engine.evaluate(ItemEngineFixtures.hour(actual: 30, apparent: 5), for: item)
            #expect(apparent?.reason == .temperature(celsius: 5))
            #expect(engine.evaluate(ItemEngineFixtures.hour(actual: nil, apparent: 5), for: item) == apparent)
            #expect(engine.evaluate(ItemEngineFixtures.hour(actual: 5), for: item) == apparent)
            #expect(engine.evaluate(ItemEngineFixtures.hour(actual: nil), for: item) == nil)
            // Unusable apparent temperature retains the actual-temperature fallback.
            for invalid in [Double.nan, .infinity, -.infinity] {
                #expect(engine.evaluate(ItemEngineFixtures.hour(actual: invalid), for: item) == nil)
                #expect(engine.evaluate(ItemEngineFixtures.hour(actual: 5, apparent: invalid), for: item) == apparent)
                #expect(engine.evaluate(ItemEngineFixtures.hour(actual: nil, apparent: invalid), for: item) == nil)
            }
            // Unrelated moisture/sky inputs must not import jacket restrictions.
            #expect(engine.evaluate(ItemEngineFixtures.hour(
                actual: 5, amount: nil, chance: nil, type: .unknown, fog: .fog, daylight: nil, sky: nil
            ), for: item) == apparent)
        }
    }

    @Test func raincoatUsesTotalWaterEquivalentAcrossEveryPrecipitationType() {
        let types: [PrecipitationType?] = [nil, PrecipitationType.none, .unknown, .rain, .drizzle, .snow, .sleet, .hail, .mixed]
        for type in types {
            for (amount, expected) in [(0.0, ItemAdviceLevel.no), (0.49, .maybe), (0.5, .yes), (3, .yes)] {
                let result = engine.evaluate(ItemEngineFixtures.hour(
                    actual: nil, amount: amount, type: type, daylight: nil, sky: nil
                ), for: .raincoat)
                #expect(result?.level == expected)
            }
        }
    }

    @Test func raincoatHonorsChanceAndPositiveLightPrecipitationWindUpgrade() {
        let cases: [(Double, Double, Double?, ItemAdviceLevel, ItemAdviceReason)] = [
            (0, 0.29, nil, .no, .dryWeather), (0, 0.30, nil, .maybe, .precipitationChance),
            (0, 1, 80, .maybe, .precipitationChance), (0, 0, 80, .no, .dryWeather),
            (0.01, 0, 29.99, .maybe, .lightPrecipitation), (0.01, 0, 30, .yes, .windDrivenPrecipitation),
            (0.49, 0.9, 30, .yes, .windDrivenPrecipitation), (0.5, 0, nil, .yes, .precipitation)
        ]
        for (amount, chance, wind, level, reason) in cases {
            #expect(engine.evaluate(ItemEngineFixtures.hour(
                actual: 40, amount: amount, chance: chance, wind: wind
            ), for: .raincoat) == ItemHourlyAdvice(level: level, reason: reason))
        }
        for wind in [nil, Double.nan, .infinity, -1] {
            #expect(engine.evaluate(ItemEngineFixtures.hour(amount: 0.1, wind: wind), for: .raincoat)?.level == .maybe)
        }
    }

    @Test func raincoatRejectsMissingOrInvalidRequiredSignals() {
        for amount in [nil, -1, Double.nan, .infinity] {
            #expect(engine.evaluate(ItemEngineFixtures.hour(amount: amount), for: .raincoat) == nil)
        }
        for chance in [nil, -0.01, 1.01, Double.nan, .infinity] {
            #expect(engine.evaluate(ItemEngineFixtures.hour(amount: 1, chance: chance), for: .raincoat) == nil)
        }
    }

    @Test func sunglassesDaylightSkyAndUVBoundaries() {
        for (sky, level, reason) in [
            (SkyCondition.clear, ItemAdviceLevel.yes, ItemAdviceReason.sunshine),
            (.mainlyClear, .yes, .sunshine), (.partlyCloudy, .maybe, .partlyCloudy),
            (.overcast, .no, .overcast), (.fogOrMist, .no, .fogOrMist)
        ] {
            for uv in [nil, 5.9, -1, Double.nan, .infinity] {
                #expect(engine.evaluate(ItemEngineFixtures.hour(sky: sky, uv: uv), for: .sunglasses)
                    == ItemHourlyAdvice(level: level, reason: reason))
            }
            #expect(engine.evaluate(ItemEngineFixtures.hour(sky: sky, uv: 6), for: .sunglasses)
                == ItemHourlyAdvice(level: .yes, reason: .highUV))
            #expect(engine.evaluate(ItemEngineFixtures.hour(daylight: false, sky: sky, uv: 9), for: .sunglasses)
                == ItemHourlyAdvice(level: .no, reason: .night))
        }
    }

    @Test func missingDaylightOrSkyCannotBeRescuedByUVOrNight() {
        for uv in [nil, 9.0] {
            #expect(engine.evaluate(ItemEngineFixtures.hour(daylight: nil, uv: uv), for: .sunglasses) == nil)
            #expect(engine.evaluate(ItemEngineFixtures.hour(sky: nil, uv: uv), for: .sunglasses) == nil)
            #expect(engine.evaluate(ItemEngineFixtures.hour(daylight: false, sky: nil, uv: uv), for: .sunglasses) == nil)
        }
        #expect(engine.evaluate(ItemEngineFixtures.hour(
            actual: nil, amount: nil, chance: nil, type: .unknown, sky: .clear
        ), for: .sunglasses)?.level == .yes)
    }

    @Test func jacketHourlyAdapterMatchesOriginalEngineIncludingReasonPrecedence() {
        let cases = [
            ItemEngineFixtures.hour(), ItemEngineFixtures.hour(actual: 18), ItemEngineFixtures.hour(actual: 24),
            ItemEngineFixtures.hour(chance: 0.10), ItemEngineFixtures.hour(amount: 1, fog: .fog),
            ItemEngineFixtures.hour(fog: .mist), ItemEngineFixtures.hour(type: .unknown)
        ]
        for hour in cases {
            let original = JacketDecisionEngine().evaluate(hour)
            #expect(engine.evaluate(hour, for: .leatherJacket) == original.map(ItemHourlyAdvice.init(jacket:)))
        }
    }
}
