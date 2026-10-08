import Foundation
import Testing
@testable import Can_I_Wear

struct DayPeriodEngineTests {
    private let engine = DayPeriodEngine()
    private let start = Date(timeIntervalSince1970: 1_791_201_600)

    @Test func stableWeatherProducesOnePeriod() {
        let periods = engine.periods(for: evaluation([.okay, .okay, .okay, .okay]))

        #expect(periods.count == 1)
        #expect(periods.first?.recommendation.level == .okay)
        #expect(periods.first?.interval == DateInterval(start: start, duration: 4 * 3_600))
    }

    @Test func groupsOrderedMaterialChangesWithoutOverlap() {
        let periods = engine.periods(for: evaluation([
            .avoid, .avoid, .avoid,
            .okay, .okay, .okay,
            .caution, .caution, .caution
        ]))

        #expect(periods.map(\.recommendation.level) == [.avoid, .okay, .caution])
        #expect(periods[0].interval.end == periods[1].interval.start)
        #expect(periods[1].interval.end == periods[2].interval.start)
    }

    @Test func expandsOneAvoidHourBackwardIntoTwoHourSafetyPeriod() {
        let periods = engine.periods(for: evaluation([
            .okay, .okay, .okay, .avoid, .okay, .okay, .okay
        ]))

        #expect(periods.map(\.recommendation.level) == [.okay, .avoid, .okay])
        #expect(periods[1].interval.duration == 2 * 3_600)
        #expect(periods[1].interval.start == start.addingTimeInterval(2 * 3_600))
    }

    @Test func expandsStartingAvoidHourForward() {
        let periods = engine.periods(for: evaluation([
            .avoid, .okay, .okay, .okay, .okay
        ]))

        #expect(periods.map(\.recommendation.level) == [.avoid, .okay])
        #expect(periods[0].interval.duration == 2 * 3_600)
    }

    @Test func absorbsShortSaferGapIntoSurroundingRisk() {
        let periods = engine.periods(for: evaluation([
            .avoid, .avoid, .avoid,
            .okay, .okay,
            .avoid, .avoid, .avoid
        ]))

        #expect(periods.count == 1)
        #expect(periods.first?.recommendation.level == .avoid)
    }

    @Test func normalShortChangeDoesNotBecomeASeparatePeriod() {
        let periods = engine.periods(for: evaluation([
            .okay, .okay, .okay,
            .caution, .caution,
            .okay, .okay, .okay
        ]))

        #expect(periods.count == 1)
        #expect(periods.first?.recommendation.level == .okay)
    }

    @Test func repeatedHourlyAlternationUsesMostProtectiveResult() {
        let periods = engine.periods(for: evaluation([
            .okay, .caution, .avoid, .okay, .avoid, .okay
        ]))

        #expect(periods.count == 1)
        #expect(periods.first?.recommendation.level == .avoid)
    }

    @Test func retainsRainReasonWhenConsolidatingNoise() {
        let recommendations = [
            recommendation(.okay),
            recommendation(.avoid, reason: .precipitation),
            recommendation(.okay)
        ]
        let periods = engine.periods(for: evaluation(recommendations))

        #expect(periods.contains { $0.recommendation.reason == .precipitation })
    }

    @Test func retainsFogReasonWhenGroupingAvoidHours() {
        let periods = engine.periods(for: evaluation([
            recommendation(.avoid, reason: .fogOrMist),
            recommendation(.avoid, reason: .fogOrMist),
            recommendation(.avoid, reason: .fogOrMist),
            recommendation(.okay),
            recommendation(.okay),
            recommendation(.okay)
        ]))

        #expect(periods.first?.recommendation.reason == .fogOrMist)
    }

    private func evaluation(_ levels: [RecommendationLevel]) -> DailyEvaluation {
        evaluation(levels.map { recommendation($0) })
    }

    private func evaluation(_ recommendations: [HourlyRecommendation]) -> DailyEvaluation {
        DailyEvaluation(
            interval: DateInterval(start: start, duration: TimeInterval(recommendations.count * 3_600)),
            timezoneIdentifier: "Europe/Brussels",
            hours: recommendations.enumerated().map { offset, recommendation in
                EvaluatedHour(
                    timestamp: start.addingTimeInterval(TimeInterval(offset * 3_600)),
                    recommendation: recommendation
                )
            }
        )
    }

    private func recommendation(
        _ level: RecommendationLevel,
        reason: RecommendationReason? = nil
    ) -> HourlyRecommendation {
        let defaultReason: RecommendationReason = switch level {
        case .okay: .suitableTemperature
        case .caution: .warmTemperature
        case .avoid: .excessiveHeat
        }
        return HourlyRecommendation(
            level: level,
            reason: reason ?? defaultReason
        )
    }
}
