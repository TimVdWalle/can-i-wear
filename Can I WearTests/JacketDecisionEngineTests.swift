import Foundation
import Testing
@testable import Can_I_Wear

struct JacketDecisionEngineTests {
    private let engine = JacketDecisionEngine()

    @Test func appliesTemperatureBoundaries() {
        #expect(engine.evaluate(hour(actual: 12))?.level == .okay)
        #expect(engine.evaluate(hour(actual: 15))?.level == .okay)
        #expect(engine.evaluate(hour(actual: 15.0001))?.level == .caution)
        #expect(engine.evaluate(hour(actual: 20))?.level == .caution)
        #expect(engine.evaluate(hour(actual: 20.0001))?.level == .avoid)
    }

    @Test func usesWarmerAvailableTemperature() {
        #expect(engine.evaluate(hour(actual: 12, apparent: 21))?.level == .avoid)
        #expect(engine.evaluate(hour(actual: 21, apparent: 12))?.level == .avoid)
        #expect(engine.evaluate(hour(actual: nil, apparent: 18))?.level == .caution)
        #expect(engine.evaluate(hour(actual: 14, apparent: nil))?.level == .okay)
    }

    @Test func appliesPrecipitationChanceBoundariesAtZeroAmount() {
        #expect(engine.evaluate(hour(chance: 0.0999))?.level == .okay)
        #expect(engine.evaluate(hour(chance: 0.10))?.level == .caution)
        #expect(engine.evaluate(hour(chance: 0.1999))?.level == .caution)
        #expect(engine.evaluate(hour(chance: 0.20))?.level == .avoid)
    }

    @Test func anyPredictedAmountMeansAvoid() {
        let recommendation = engine.evaluate(hour(amount: 0.0001, chance: 0))

        #expect(recommendation?.level == .avoid)
        #expect(recommendation?.reason == .precipitation)
    }

    @Test func rainDominatesAcrossTemperatureAndIntensity() {
        #expect(engine.evaluate(hour(actual: 12, amount: 1)) == HourlyRecommendation(
            level: .avoid,
            reason: .precipitation
        ))
        #expect(engine.evaluate(hour(actual: 18, amount: 2.5)) == HourlyRecommendation(
            level: .avoid,
            reason: .precipitation
        ))
        #expect(engine.evaluate(hour(actual: 24, amount: 10)) == HourlyRecommendation(
            level: .avoid,
            reason: .precipitation
        ))
    }

    @Test func everyExplicitPrecipitationTypeMeansAvoid() {
        let types: [PrecipitationType] = [.drizzle, .rain, .hail, .snow, .sleet, .mixed]

        for type in types {
            #expect(engine.evaluate(hour(type: type))?.level == .avoid)
        }
    }

    @Test func explicitFogOrMistAlwaysMeansAvoid() {
        let hazards: [FogOrMistCondition] = [.mist, .fog, .depositingRimeFog]

        for hazard in hazards {
            #expect(engine.evaluate(hour(actual: 12, fogOrMist: hazard)) == HourlyRecommendation(
                level: .avoid,
                reason: .fogOrMist
            ))
            #expect(engine.evaluate(hour(actual: 24, fogOrMist: hazard))?.reason == .fogOrMist)
        }
    }

    @Test func absentOrExplicitlyClearFogSignalUsesExistingRules() {
        #expect(engine.evaluate(hour(fogOrMist: nil))?.level == .okay)
        #expect(engine.evaluate(hour(fogOrMist: FogOrMistCondition.none))?.level == .okay)
        #expect(engine.evaluate(hour(actual: 18, fogOrMist: nil))?.level == .caution)
    }

    @Test func precipitationRemainsThePrimaryReasonWhenRainAndFogOverlap() {
        #expect(engine.evaluate(hour(amount: 1, type: .rain, fogOrMist: .fog)) == HourlyRecommendation(
            level: .avoid,
            reason: .precipitation
        ))
    }

    @Test func informationalWindDoesNotChangeRecommendation() {
        let calm = hour(actual: 12)
        let windy = HourlyWeather(
            timestamp: calm.timestamp,
            timezoneIdentifier: calm.timezoneIdentifier,
            actualTemperatureCelsius: calm.actualTemperatureCelsius,
            apparentTemperatureCelsius: calm.apparentTemperatureCelsius,
            precipitationAmountMillimeters: calm.precipitationAmountMillimeters,
            precipitationType: calm.precipitationType,
            precipitationChanceFraction: calm.precipitationChanceFraction,
            fogOrMistCondition: calm.fogOrMistCondition,
            windSpeedKilometersPerHour: 120,
            windGustKilometersPerHour: 180
        )

        #expect(engine.evaluate(windy) == engine.evaluate(calm))
    }

    @Test func moreProtectiveResultWins() {
        #expect(engine.evaluate(hour(actual: 21, chance: 0.10)) == HourlyRecommendation(
            level: .avoid,
            reason: .excessiveHeat
        ))
        #expect(engine.evaluate(hour(actual: 12, chance: 0.10)) == HourlyRecommendation(
            level: .caution,
            reason: .precipitationRisk
        ))
    }

    @Test func rejectsMissingOrInvalidRequiredData() {
        #expect(engine.evaluate(hour(actual: nil, apparent: nil)) == nil)
        #expect(engine.evaluate(hour(actual: nil, apparent: nil, amount: 1)) == nil)
        #expect(engine.evaluate(hour(amount: nil)) == nil)
        #expect(engine.evaluate(hour(chance: nil)) == nil)
        #expect(engine.evaluate(hour(amount: -0.1)) == nil)
        #expect(engine.evaluate(hour(chance: 1.01)) == nil)
        #expect(engine.evaluate(hour(type: .unknown)) == nil)
        #expect(engine.evaluate(hour(actual: .nan)) == nil)
    }

    private func hour(
        actual: Double? = 12,
        apparent: Double? = 12,
        amount: Double? = 0,
        type: PrecipitationType? = PrecipitationType.none,
        chance: Double? = 0,
        fogOrMist: FogOrMistCondition? = nil
    ) -> HourlyWeather {
        HourlyWeather(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            timezoneIdentifier: "Europe/Brussels",
            actualTemperatureCelsius: actual,
            apparentTemperatureCelsius: apparent,
            precipitationAmountMillimeters: amount,
            precipitationType: type,
            precipitationChanceFraction: chance,
            fogOrMistCondition: fogOrMist
        )
    }
}
