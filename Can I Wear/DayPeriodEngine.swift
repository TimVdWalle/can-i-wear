import Foundation

nonisolated struct DayPeriod: Equatable, Sendable {
    let interval: DateInterval
    let timezoneIdentifier: String
    let recommendation: HourlyRecommendation
}

nonisolated struct DayPeriodEngine: Sendable {
    private let config: DayPeriodConfig

    init(config: DayPeriodConfig = AppConfiguration.dayPeriods) {
        self.config = config
    }

    func periods(for evaluation: DailyEvaluation) -> [DayPeriod] {
        guard !evaluation.hours.isEmpty else { return [] }

        var hours = evaluation.hours
        consolidateAlternatingSpans(in: &hours)
        absorbShortChanges(in: &hours)
        expandIsolatedAvoidHours(in: &hours)

        return groupedPeriods(from: hours, evaluation: evaluation)
    }

    private func consolidateAlternatingSpans(in hours: inout [EvaluatedHour]) {
        guard hours.count >= config.minimumNoisyAlternationHours else { return }

        let original = hours
        let runs = levelRuns(in: original)
        var runStart = runs.startIndex
        while runStart < runs.endIndex {
            guard runs[runStart].range.count == 1 else {
                runStart += 1
                continue
            }

            var runEnd = runStart
            while runEnd + 1 < runs.endIndex, runs[runEnd + 1].range.count == 1 {
                runEnd += 1
            }

            if runEnd - runStart + 1 >= config.minimumNoisyAlternationHours {
                let hourStart = runs[runStart].range.lowerBound
                let hourEnd = runs[runEnd].range.upperBound - 1
                if let recommendation = HourlyRecommendation.mostProtective(
                    in: original[hourStart...hourEnd].map(\.recommendation)
                ) {
                    for index in hourStart...hourEnd {
                        hours[index] = EvaluatedHour(
                            timestamp: hours[index].timestamp,
                            recommendation: recommendation
                        )
                    }
                }
            }
            runStart = runEnd + 1
        }
    }

    private func expandIsolatedAvoidHours(in hours: inout [EvaluatedHour]) {
        guard config.isolatedAvoidSafetyHours > 1, hours.count > 1 else { return }

        let runs = levelRuns(in: hours)
        for run in runs.reversed()
        where run.level == .avoid && run.range.count == 1 {
            let source = hours[run.range.lowerBound].recommendation
            var expansionIndices: [Int] = []
            var candidate = run.range.lowerBound
            while expansionIndices.count < config.isolatedAvoidSafetyHours - 1,
                  candidate > hours.startIndex {
                candidate = hours.index(before: candidate)
                expansionIndices.append(candidate)
            }
            candidate = run.range.upperBound
            while expansionIndices.count < config.isolatedAvoidSafetyHours - 1,
                  candidate < hours.endIndex {
                expansionIndices.append(candidate)
                candidate = hours.index(after: candidate)
            }

            for index in expansionIndices {
                hours[index] = EvaluatedHour(
                    timestamp: hours[index].timestamp,
                    recommendation: source
                )
            }
        }
    }

    private func absorbShortChanges(in hours: inout [EvaluatedHour]) {
        while true {
            let runs = levelRuns(in: hours)
            guard runs.count > 1 else { return }

            var changed = false
            for (runIndex, run) in runs.enumerated() {
                guard run.range.count < config.minimumMeaningfulChangeHours else { continue }
                if run.level == .avoid {
                    continue
                }

                let previous = runIndex > runs.startIndex ? runs[runIndex - 1] : nil
                let next = runIndex < runs.index(before: runs.endIndex) ? runs[runIndex + 1] : nil
                guard let replacement = replacementRecommendation(
                    for: run,
                    previous: previous,
                    next: next,
                    hours: hours
                ) else { continue }

                for index in run.range {
                    hours[index] = EvaluatedHour(
                        timestamp: hours[index].timestamp,
                        recommendation: replacement
                    )
                }
                changed = true
                break
            }

            if !changed { return }
        }
    }

    private func replacementRecommendation(
        for run: LevelRun,
        previous: LevelRun?,
        next: LevelRun?,
        hours: [EvaluatedHour]
    ) -> HourlyRecommendation? {
        let replacementRun: LevelRun?
        switch (previous, next) {
        case let (.some(previous), .some(next)) where previous.level == next.level:
            replacementRun = previous
        case let (.some(previous), .some(next)):
            replacementRun = previous.level >= next.level ? previous : next
        case let (.some(previous), .none):
            replacementRun = previous
        case let (.none, .some(next)):
            replacementRun = next
        case (.none, .none):
            replacementRun = nil
        }

        guard let replacementRun else { return nil }
        return HourlyRecommendation.mostProtective(
            in: replacementRun.range.map { hours[$0].recommendation }
        )
    }

    private func groupedPeriods(
        from hours: [EvaluatedHour],
        evaluation: DailyEvaluation
    ) -> [DayPeriod] {
        levelRuns(in: hours).compactMap { run in
            guard let recommendation = HourlyRecommendation.mostProtective(
                in: run.range.map { hours[$0].recommendation }
            ) else { return nil }

            let end = run.range.upperBound < hours.endIndex
                ? hours[run.range.upperBound].timestamp
                : evaluation.interval.end
            return DayPeriod(
                interval: DateInterval(
                    start: hours[run.range.lowerBound].timestamp,
                    end: end
                ),
                timezoneIdentifier: evaluation.timezoneIdentifier,
                recommendation: recommendation
            )
        }
    }

    private func levelRuns(in hours: [EvaluatedHour]) -> [LevelRun] {
        guard let first = hours.first else { return [] }

        var runs: [LevelRun] = []
        var start = hours.startIndex
        var level = first.recommendation.level
        for index in hours.indices.dropFirst() {
            let candidate = hours[index].recommendation.level
            if candidate != level {
                runs.append(LevelRun(level: level, range: start..<index))
                start = index
                level = candidate
            }
        }
        runs.append(LevelRun(level: level, range: start..<hours.endIndex))
        return runs
    }
}

nonisolated private struct LevelRun {
    let level: RecommendationLevel
    let range: Range<Int>
}
