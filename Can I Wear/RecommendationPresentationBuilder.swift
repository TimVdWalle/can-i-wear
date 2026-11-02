import Foundation

/// Deterministic forecast-to-presentation mapping. Request/cache policy and diagnostic recording stay with the caller.
nonisolated struct RecommendationPresentationBuilder: Sendable {
    struct Output: Sendable {
        let presentation: DailyRecommendationPresentation
        let jacketEvaluation: DailyEvaluation?
        let jacketPeriods: [DayPeriod]
        let remainingHourCount: Int
    }

    private let dailyEngine: DailyRecommendationEngine
    private let periodEngine: DayPeriodEngine
    private let itemEngine = MultiItemRecommendationEngine()

    init(
        dailyEngine: DailyRecommendationEngine = DailyRecommendationEngine(),
        periodEngine: DayPeriodEngine = DayPeriodEngine()
    ) {
        self.dailyEngine = dailyEngine
        self.periodEngine = periodEngine
    }

    func build(
        from forecast: NormalizedForecast,
        for selectedItems: [PredefinedItem],
        at currentTime: Date,
        isUsingSavedWeather: Bool,
        isRefreshing: Bool,
        refreshFailed: Bool,
        refreshAvailableAt: Date
    ) -> Output? {
        guard let window = ForecastEvaluationWindow(forecast: forecast, now: currentTime) else { return nil }
        let itemResults = itemEngine.evaluate(forecast, for: selectedItems, now: currentTime)
        let evaluation = dailyEngine.evaluateHours(forecast, now: currentTime)
        let periods = evaluation.map { periodEngine.periods(for: $0) } ?? []
        let displayEvaluation = dailyEngine.evaluateDisplayHours(forecast, now: currentTime)
            ?? evaluation
        let planningStart = ForecastEvaluationWindow(forecast: forecast, now: currentTime, includesPlanningMorning: true)?.interval.start
        let itemPlanningResults = planningStart.map { itemEngine.evaluate(forecast, for: selectedItems, now: $0) } ?? []
        let displayHours = (displayEvaluation?.hours ?? []).map {
            HourlySuitabilityPresentation(
                hour: $0,
                timezoneIdentifier: window.timezoneIdentifier,
                isPast: $0.timestamp.addingTimeInterval(3_600) <= currentTime
            )
        }

        let presentation = DailyRecommendationPresentation(
            periods: periods.map {
                PeriodPresentation(
                    interval: $0.interval,
                    timezoneIdentifier: $0.timezoneIdentifier,
                    recommendation: RecommendationPresentation(recommendation: $0.recommendation)
                )
            },
            hours: (evaluation?.hours ?? []).map {
                HourlySuitabilityPresentation(hour: $0, timezoneIdentifier: window.timezoneIdentifier)
            },
            weatherFetchedAt: forecast.metadata.fetchedAt,
            isUsingSavedWeather: isUsingSavedWeather,
            isRefreshing: isRefreshing,
            refreshFailed: refreshFailed,
            refreshAvailableAt: refreshAvailableAt,
            dayParts: displayEvaluation.map { FixedDayPartPresentation.make(from: $0, at: currentTime) } ?? [],
            displayHours: displayHours,
            itemResults: itemResults,
            itemPlanningResults: itemPlanningResults,
            evaluationHour: window.interval.start
        )
        return Output(
            presentation: presentation,
            jacketEvaluation: evaluation,
            jacketPeriods: periods,
            remainingHourCount: window.slots.count
        )
    }
}
