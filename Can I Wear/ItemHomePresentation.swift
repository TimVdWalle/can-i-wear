import Foundation

nonisolated extension PredefinedItem {
    var name: String {
        switch self {
        case .leatherJacket: "Leather Jacket"
        case .warmCoat: "Warm Coat"
        case .sweater: "Sweater"
        case .raincoat: "Raincoat"
        case .sunglasses: "Sunglasses"
        case .shorts: "Shorts"
        case .gloves: "Gloves"
        }
    }

    var symbolName: String {
        switch self {
        case .leatherJacket, .warmCoat: "tshirt.fill"
        case .sweater: "tshirt"
        case .raincoat: "umbrella.fill"
        case .sunglasses: "eyeglasses"
        case .shorts: "figure.walk"
        case .gloves: "hand.raised.fill"
        }
    }
}

nonisolated enum ItemAdviceTone: Equatable, Sendable {
    case positive
    case caution
    case negative
    case neutral
}

nonisolated struct ItemHomePresentation: Identifiable, Equatable, Sendable {
    let result: ItemForecastResult
    var id: PredefinedItem { result.item }
    var evaluation: ItemDailyEvaluation? { result.evaluation }

    var title: String {
        guard let evaluation else { return "Not enough forecast data" }
        switch evaluation.verdict {
        case .goodForRemainingDay: return "Good for the rest of today"
        case .useful: return "Useful today"
        case .brieflyUseful: return "Briefly useful"
        case .maybeUseful:
            return evaluation.reasons.contains(.incompleteForecast) ? "Forecast uncertain" : "May be useful"
        case .notNeeded: return "Not needed today"
        case .caution:
            return evaluation.reasons.contains(.incompleteForecast) ? "Forecast uncertain" : "Wear with caution"
        case .restricted:
            let reasons = relevantReasons
            if reasons.count > 1 { return "Avoid at these times" }
            switch reasons.first {
            case .jacket(.fogOrMist): return "Avoid during fog or mist"
            case .jacket(.excessiveHeat): return "Avoid the heat"
            case .incompleteForecast: return "Avoid: forecast uncertain"
            default: return "Avoid during wet weather"
            }
        }
    }

    var tone: ItemAdviceTone {
        guard let verdict = evaluation?.verdict else { return .neutral }
        switch verdict {
        case .goodForRemainingDay, .useful: return .positive
        case .brieflyUseful, .maybeUseful, .caution: return .caution
        case .restricted: return .negative
        case .notNeeded: return .neutral
        }
    }

    var reason: String {
        guard evaluation != nil else { return "Cannot assess the remaining day." }
        let temperatures = relevantReasons.compactMap { reason -> Double? in
            if case .temperature(let value) = reason { return value }
            return nil
        }
        if let low = temperatures.min(), let high = temperatures.max(), temperatures.count == relevantReasons.count {
            let lower = low.formatted(.number.precision(.fractionLength(0...1)))
            let upper = high.formatted(.number.precision(.fractionLength(0...1)))
            return low == high ? "Temperature: \(lower)°C." : "Temperature: \(lower)–\(upper)°C."
        }
        return relevantReasons.map(Self.reasonText).joined(separator: " · ")
    }

    private var relevantReasons: [ItemAdviceReason] {
        guard let evaluation else { return [] }
        // Keep the jacket's primary reason first, but do not hide other actual restrictions.
        var reasons = evaluation.reasons
        if evaluation.verdict == .restricted {
            for hour in evaluation.hours where hour.advice.level == .no {
                if !reasons.contains(hour.advice.reason) { reasons.append(hour.advice.reason) }
            }
        }
        return reasons
    }

    var timing: String {
        guard let evaluation else { return "Required weather inputs are missing." }
        let level: ItemAdviceLevel?
        switch evaluation.verdict {
        case .useful, .brieflyUseful: level = .yes
        case .maybeUseful, .caution: level = .maybe
        case .restricted: level = .no
        case .goodForRemainingDay, .notNeeded: level = nil
        }
        let periods = level.map { target in evaluation.periods.filter { $0.level == target } } ?? []
        // Jacket consolidation can absorb a raw caution. Fall back to those actual hours,
        // never replace a daily caution with the smoothed period's optimistic result.
        var intervals: [DateInterval]
        if level != nil, periods.isEmpty {
            intervals = evaluation.hours.filter { $0.advice.level == level }.map {
                DateInterval(start: $0.timestamp, duration: 3_600)
            }
        } else {
            intervals = periods.isEmpty ? [evaluation.interval] : periods.map(\.interval)
        }
        if evaluation.item == .leatherJacket, let level {
            for hour in evaluation.hours where hour.advice.level == level {
                if !intervals.contains(where: { hour.timestamp >= $0.start && hour.timestamp < $0.end }) {
                    intervals.append(DateInterval(start: hour.timestamp, duration: 3_600))
                }
            }
            var merged: [DateInterval] = []
            for interval in intervals.sorted(by: { $0.start < $1.start }) {
                if let previous = merged.last, interval.start <= previous.end {
                    merged[merged.count - 1] = DateInterval(start: previous.start, end: max(previous.end, interval.end))
                } else {
                    merged.append(interval)
                }
            }
            intervals = merged
        }
        return intervals.map { Self.range($0, timezone: evaluation.timezoneIdentifier) }.joined(separator: " · ")
    }

    var uncertaintyNote: String? {
        evaluation?.hours.contains(where: \.isInferred) == true ? "One forecast hour is uncertain." : nil
    }

    var accessibilityLabel: String {
        ["\(id.name). \(title). \(timing). \(reason)", uncertaintyNote].compactMap { $0 }.joined(separator: " ")
    }

    static func levelTitle(_ level: ItemAdviceLevel, item: PredefinedItem, inferred: Bool = false) -> String {
        if inferred { return "Uncertain" }
        switch level {
        case .yes: return item == .leatherJacket ? "Suitable" : "Useful"
        case .maybe: return item == .leatherJacket ? "Caution" : "Maybe useful"
        case .no: return item == .leatherJacket ? "Avoid" : "Not needed"
        }
    }

    static func tone(_ level: ItemAdviceLevel, item: PredefinedItem, inferred: Bool = false) -> ItemAdviceTone {
        if inferred { return .caution }
        switch level {
        case .yes: return .positive
        case .maybe: return .caution
        case .no: return item == .leatherJacket ? .negative : .neutral
        }
    }

    static func reasonText(_ reason: ItemAdviceReason) -> String {
        switch reason {
        case .jacket(let reason):
            return RecommendationPresentation(recommendation: HourlyRecommendation(level: .avoid, reason: reason)).reason
        case .temperature(let value): return "Temperature: \(value.formatted(.number.precision(.fractionLength(0...1))))°C."
        case .precipitation: return "Precipitation is expected."
        case .lightPrecipitation: return "Light precipitation is expected."
        case .precipitationChance: return "Precipitation is possible."
        case .windDrivenPrecipitation: return "Wind-driven precipitation is expected."
        case .dryWeather: return "Dry forecast."
        case .sunshine: return "Sunny conditions."
        case .partlyCloudy: return "Partly cloudy skies."
        case .overcast: return "Overcast skies."
        case .fogOrMist: return "Fog or mist."
        case .night: return "Outside daylight hours."
        case .highUV: return "High UV is forecast."
        case .incompleteForecast: return "Part of the forecast is uncertain."
        }
    }

    static func range(_ interval: DateInterval, timezone: String) -> String {
        let zone = TimeZone(identifier: timezone) ?? .gmt
        let offsets = zone.secondsFromGMT(for: interval.start) != zone.secondsFromGMT(for: interval.end)
        let start = HomeTime.label(interval.start, timezone: timezone, offset: offsets)
        let endLabel = HomeTime.label(interval.end, timezone: timezone, offset: offsets)
        let end = endLabel.hasPrefix("00:00") ? "24:00" + endLabel.dropFirst(5) : endLabel
        return "\(start)–\(end)"
    }
}

extension PredefinedItem: Identifiable {
    nonisolated var id: Self { self }
}
