import Foundation

/// One normalized forecast, two daily policies. No fetching, caching, UI strings or settings.
nonisolated struct MultiItemRecommendationEngine: Sendable {
    private let config: ItemRulesConfig
    private let hourlyEngine: ItemDecisionEngine
    private let jacketDailyEngine: DailyRecommendationEngine
    private let jacketPeriodEngine: DayPeriodEngine

    init(
        config: ItemRulesConfig = AppConfiguration.itemRules,
        jacketEngine: JacketDecisionEngine = JacketDecisionEngine(),
        jacketPeriodEngine: DayPeriodEngine = DayPeriodEngine()
    ) {
        self.config = config
        self.hourlyEngine = ItemDecisionEngine(config: config, jacketEngine: jacketEngine)
        self.jacketDailyEngine = DailyRecommendationEngine(hourlyEngine: jacketEngine)
        self.jacketPeriodEngine = jacketPeriodEngine
    }

    func evaluate(
        _ forecast: NormalizedForecast,
        for items: [PredefinedItem] = PredefinedItem.allCases,
        now: Date
    ) -> [ItemForecastResult] {
        var seen: Set<PredefinedItem> = []
        return items.filter { seen.insert($0).inserted }.map { item in
            ItemForecastResult(item: item, evaluation: evaluate(forecast, for: item, now: now))
        }
    }

    func evaluate(
        _ forecast: NormalizedForecast, for item: PredefinedItem, now: Date
    ) -> ItemDailyEvaluation? {
        switch item.dailyPolicy {
        case .canIWear: return evaluateJacket(forecast, now: now)
        case .shouldIWear: return evaluateUsefulness(forecast, for: item, now: now)
        }
    }

    private func evaluateJacket(_ forecast: NormalizedForecast, now: Date) -> ItemDailyEvaluation? {
        guard let evaluation = jacketDailyEngine.evaluateHours(forecast, now: now),
              let summary = HourlyRecommendation.mostProtective(
                in: evaluation.hours.map(\.recommendation)
              ) else { return nil }
        let verdict: ItemDailyVerdict
        switch summary.level {
        case .okay: verdict = .goodForRemainingDay
        case .caution: verdict = .caution
        case .avoid: verdict = .restricted
        }
        let hours = evaluation.hours.map {
            EvaluatedItemHour(timestamp: $0.timestamp, advice: ItemHourlyAdvice(jacket: $0.recommendation))
        }
        let periods = jacketPeriodEngine.periods(for: evaluation).map { period in
            let advice = ItemHourlyAdvice(jacket: period.recommendation)
            return ItemAdvicePeriod(
                interval: period.interval,
                timezoneIdentifier: period.timezoneIdentifier,
                level: advice.level,
                reasons: [advice.reason],
                isInferred: advice.reason == .incompleteForecast
            )
        }
        return ItemDailyEvaluation(
            item: .leatherJacket, interval: evaluation.interval,
            timezoneIdentifier: evaluation.timezoneIdentifier, verdict: verdict,
            reasons: [ItemHourlyAdvice(jacket: summary).reason], hours: hours, periods: periods
        )
    }

    private func evaluateUsefulness(
        _ forecast: NormalizedForecast, for item: PredefinedItem, now: Date
    ) -> ItemDailyEvaluation? {
        guard let window = ForecastEvaluationWindow(forecast: forecast, now: now) else { return nil }
        var advice = window.slots.map { slot in
            slot.weather.flatMap { hourlyEngine.evaluate($0, for: item) }
        }
        let missing = advice.indices.filter { advice[$0] == nil }
        if missing.count == 1, let index = missing.first {
            guard index > advice.startIndex, index < advice.index(before: advice.endIndex),
                  advice[index - 1] != nil, advice[index + 1] != nil else { return nil }
            advice[index] = ItemHourlyAdvice(level: .maybe, reason: .incompleteForecast)
        } else if !missing.isEmpty {
            return nil
        }
        let hours = zip(window.slots, advice).compactMap { slot, recommendation in
            recommendation.map { EvaluatedItemHour(timestamp: slot.timestamp, advice: $0) }
        }
        guard !hours.isEmpty, hours.count == window.slots.count else { return nil }
        let count = hours.filter { $0.advice.level == .yes && !$0.isInferred }.count
        let verdict: ItemDailyVerdict
        if count >= config.minimumUsefulHours {
            verdict = .useful
        } else if count > 0 {
            verdict = .brieflyUseful
        } else if hours.contains(where: { $0.advice.level == .maybe }) {
            verdict = .maybeUseful
        } else {
            verdict = .notNeeded
        }
        return ItemDailyEvaluation(
            item: item, interval: window.interval, timezoneIdentifier: window.timezoneIdentifier,
            verdict: verdict, reasons: summaryReasons(hours, usefulCount: count), hours: hours,
            periods: contiguousPeriods(hours, timezoneIdentifier: window.timezoneIdentifier)
        )
    }

    private func summaryReasons(_ hours: [EvaluatedItemHour], usefulCount: Int) -> [ItemAdviceReason] {
        let level: ItemAdviceLevel = usefulCount > 0 ? .yes
            : hours.contains { $0.advice.level == .maybe } ? .maybe : .no
        var reasons: [ItemAdviceReason] = []
        for hour in hours where hour.advice.level == level {
            if !reasons.contains(hour.advice.reason) { reasons.append(hour.advice.reason) }
        }
        return reasons
    }

    /// D-069: do not bridge another level, an inferred hour, or a timestamp gap.
    private func contiguousPeriods(
        _ hours: [EvaluatedItemHour], timezoneIdentifier: String
    ) -> [ItemAdvicePeriod] {
        var periods: [ItemAdvicePeriod] = []
        for hour in hours {
            if let previous = periods.last, previous.interval.end == hour.timestamp,
               previous.level == hour.advice.level, previous.isInferred == hour.isInferred {
                var reasons = previous.reasons
                if !reasons.contains(hour.advice.reason) { reasons.append(hour.advice.reason) }
                periods[periods.count - 1] = ItemAdvicePeriod(
                    interval: DateInterval(start: previous.interval.start, duration: previous.interval.duration + 3_600),
                    timezoneIdentifier: timezoneIdentifier, level: previous.level,
                    reasons: reasons, isInferred: previous.isInferred
                )
            } else {
                periods.append(ItemAdvicePeriod(
                    interval: DateInterval(start: hour.timestamp, duration: 3_600),
                    timezoneIdentifier: timezoneIdentifier, level: hour.advice.level,
                    reasons: [hour.advice.reason], isInferred: hour.isInferred
                ))
            }
        }
        return periods
    }
}
