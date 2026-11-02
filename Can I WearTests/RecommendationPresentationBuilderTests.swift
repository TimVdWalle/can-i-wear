import Foundation
import Testing
@testable import Can_I_Wear

struct RecommendationPresentationBuilderTests {
    private let start = ItemEngineFixtures.dayEnd.addingTimeInterval(-18 * 3_600)

    @Test func mapsRemainingAndPlanningOutputsWithoutChangingEngineResults() throws {
        let forecast = fixture()
        let now = start.addingTimeInterval(8.5 * 3_600)
        let output = try #require(build(forecast, at: now))
        let presentation = output.presentation
        let engine = DailyRecommendationEngine()
        let remaining = try #require(engine.evaluateHours(forecast, now: now))
        let planning = try #require(engine.evaluateDisplayHours(forecast, now: now))
        let periods = DayPeriodEngine().periods(for: remaining)

        #expect(output.jacketEvaluation == remaining)
        #expect(output.jacketPeriods == periods)
        #expect(output.remainingHourCount == 10)
        #expect(presentation.hours == remaining.hours.map {
            HourlySuitabilityPresentation(hour: $0, timezoneIdentifier: "UTC")
        })
        #expect(presentation.periods == periods.map {
            PeriodPresentation(interval: $0.interval, timezoneIdentifier: "UTC",
                               recommendation: RecommendationPresentation(recommendation: $0.recommendation))
        })
        #expect(presentation.itemResults == MultiItemRecommendationEngine().evaluate(forecast, now: now))
        #expect(presentation.itemPlanningResults == MultiItemRecommendationEngine().evaluate(forecast, now: start))
        #expect(presentation.dayParts == FixedDayPartPresentation.make(from: planning, at: now))
        #expect(presentation.displayHours.map(\.hour) == planning.hours)
        #expect(presentation.displayHours.map(\.isPast) == (0..<18).map { $0 < 8 })
        #expect(presentation.weatherFetchedAt == forecast.metadata.fetchedAt)
        #expect(presentation.evaluationHour == start.addingTimeInterval(8 * 3_600))
    }

    @Test func preservesCallerSuppliedRefreshStateAndIsDeterministic() throws {
        let forecast = fixture()
        let availableAt = start.addingTimeInterval(1_234)
        for saved in [false, true] {
            for refreshing in [false, true] {
                for failed in [false, true] {
                    let builder = RecommendationPresentationBuilder()
                    let first = try #require(builder.build(
                        from: forecast, for: [.sunglasses], at: start,
                        isUsingSavedWeather: saved, isRefreshing: refreshing,
                        refreshFailed: failed, refreshAvailableAt: availableAt
                    ))
                    let second = try #require(builder.build(
                        from: forecast, for: [.sunglasses], at: start,
                        isUsingSavedWeather: saved, isRefreshing: refreshing,
                        refreshFailed: failed, refreshAvailableAt: availableAt
                    ))
                    #expect(first.presentation == second.presentation)
                    #expect(first.presentation.isUsingSavedWeather == saved)
                    #expect(first.presentation.isRefreshing == refreshing)
                    #expect(first.presentation.refreshFailed == failed)
                    #expect(first.presentation.refreshAvailableAt == availableAt)
                    #expect(first.presentation.itemResults.map(\.item) == [.sunglasses])
                    #expect(first.jacketEvaluation != nil, "Keep the existing independent jacket diagnostics")
                }
            }
        }
    }

    @Test func rejectsAnInvalidWindowButKeepsIndependentlyAvailableItems() throws {
        let missingTimezone = NormalizedForecast(
            hours: [ItemEngineFixtures.hour(at: start, timezone: nil)], metadata: fixture().metadata
        )
        #expect(build(missingTimezone, at: start) == nil)
        #expect(build(NormalizedForecast(hours: [], metadata: fixture().metadata), at: start) == nil)

        let noJacket = fixture(missingTemperature: true)
        let output = try #require(build(noJacket, at: start))
        #expect(output.jacketEvaluation == nil)
        #expect(output.jacketPeriods.isEmpty)
        #expect(output.presentation.hours.isEmpty)
        #expect(output.presentation.dayParts.isEmpty)
        #expect(output.presentation.displayHours.isEmpty)
        #expect(output.presentation.itemResults.first { $0.item == .leatherJacket }?.evaluation == nil)
        #expect(output.presentation.itemResults.first { $0.item == .raincoat }?.evaluation != nil)
        #expect(output.presentation.itemResults.first { $0.item == .sunglasses }?.evaluation != nil)
    }

    @Test func keepsExistingRemainingHourFallbackWhenPlanningCoverageIsMissing() throws {
        let original = fixture()
        let forecast = NormalizedForecast(hours: Array(original.hours.dropFirst(8)), metadata: original.metadata)
        let now = start.addingTimeInterval(8.5 * 3_600)
        let output = try #require(build(forecast, at: now))
        #expect(output.presentation.displayHours.map(\.hour) == output.presentation.hours.map(\.hour))
        #expect(output.presentation.displayHours.allSatisfy { !$0.isPast })
        #expect(output.presentation.dayParts.map(\.dayPart) == [.morning, .afternoon, .evening])
        #expect(output.presentation.dayParts.first?.recommendation == nil)
        #expect(output.presentation.itemResults.allSatisfy { $0.evaluation != nil })
        #expect(output.presentation.itemPlanningResults.allSatisfy { $0.evaluation == nil })
    }

    @Test func retainsRawUncertaintyAndProtectivePeriodExpansion() throws {
        let original = fixture()
        let forecast = NormalizedForecast(
            hours: original.hours.enumerated().filter { $0.offset != 7 }.map(\.element), metadata: original.metadata
        )
        let presentation = try #require(build(forecast, at: start)).presentation
        #expect(presentation.hours[7].isInferred)
        #expect(presentation.displayHours[7].isInferred)
        #expect(presentation.itemResults.first { $0.item == .sunglasses }?.evaluation?.hours[7].isInferred == true)
        #expect(presentation.hasConsolidatedDifferences)
        #expect(presentation.hours[11].recommendation.level == .okay)
        #expect(presentation.periods.contains {
            $0.interval.contains(presentation.hours[11].id) && $0.recommendation.level == .avoid
        })
    }

    @Test func preservesInjectedJacketEvaluationAndGrouping() throws {
        let dailyEngine = DailyRecommendationEngine(hourlyEngine: JacketDecisionEngine(config: JacketRulesConfig(
            maximumDryPrecipitationAmountMillimeters: 0, cautionPrecipitationChanceFraction: 0.10,
            avoidPrecipitationChanceFraction: 0.20, maximumOkayTemperatureCelsius: 5,
            maximumCautionTemperatureCelsius: 10
        )))
        let periodEngine = DayPeriodEngine(config: DayPeriodConfig(
            minimumMeaningfulChangeHours: 2, isolatedAvoidSafetyHours: 3, minimumNoisyAlternationHours: 4
        ))
        let forecast = fixture()
        let builder = RecommendationPresentationBuilder(dailyEngine: dailyEngine, periodEngine: periodEngine)
        let output = try #require(builder.build(
            from: forecast, for: [.leatherJacket], at: start, isUsingSavedWeather: false,
            isRefreshing: false, refreshFailed: false, refreshAvailableAt: start
        ))
        let expected = try #require(dailyEngine.evaluateHours(forecast, now: start))
        #expect(output.jacketEvaluation == expected)
        #expect(output.jacketPeriods == periodEngine.periods(for: expected))
        #expect(output.presentation.hours.allSatisfy { $0.recommendation.level == .avoid })

        let grouping = try #require(RecommendationPresentationBuilder(periodEngine: periodEngine).build(
            from: forecast, for: [.leatherJacket], at: start, isUsingSavedWeather: false,
            isRefreshing: false, refreshFailed: false, refreshAvailableAt: start
        ))
        let defaultEvaluation = try #require(DailyRecommendationEngine().evaluateHours(forecast, now: start))
        #expect(grouping.jacketPeriods == periodEngine.periods(for: defaultEvaluation))
        #expect(grouping.jacketPeriods != DayPeriodEngine().periods(for: defaultEvaluation))
    }

    private func build(_ forecast: NormalizedForecast, at now: Date) -> RecommendationPresentationBuilder.Output? {
        RecommendationPresentationBuilder().build(
            from: forecast, for: PredefinedItem.allCases, at: now, isUsingSavedWeather: false,
            isRefreshing: false, refreshFailed: false, refreshAvailableAt: now
        )
    }

    private func fixture(missingTemperature: Bool = false) -> NormalizedForecast {
        let hours: [HourlyWeather] = (0..<18).map { index -> HourlyWeather in
            let timestamp = start.addingTimeInterval(Double(index) * 3_600)
            let temperature: Double? = missingTemperature ? nil : 12
            let amount: Double = index == 12 ? 1 : 0
            let sky: SkyCondition = index < 9 ? .clear : .overcast
            return ItemEngineFixtures.hour(
                at: timestamp, actual: temperature, amount: amount, daylight: index < 13, sky: sky
            )
        }
        return NormalizedForecast(
            hours: hours,
            metadata: ForecastMetadata(fetchedAt: start, location: LocationIdentity(latitude: 50.85, longitude: 4.35))
        )
    }
}
