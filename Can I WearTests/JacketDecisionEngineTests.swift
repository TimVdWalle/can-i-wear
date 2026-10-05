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
        chance: Double? = 0
    ) -> HourlyWeather {
        HourlyWeather(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            timezoneIdentifier: "Europe/Brussels",
            actualTemperatureCelsius: actual,
            apparentTemperatureCelsius: apparent,
            precipitationAmountMillimeters: amount,
            precipitationType: type,
            precipitationChanceFraction: chance
        )
    }
}
