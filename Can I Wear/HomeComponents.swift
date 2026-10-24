import SwiftUI

enum HomeStyle {
    static let spacing: CGFloat = 20
    static let cardRadius: CGFloat = 22
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let artBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.82, green: 0.77, blue: 0.71, alpha: 1)
            : UIColor(red: 0.95, green: 0.93, blue: 0.90, alpha: 1)
    })

    static func ink(_ level: RecommendationLevel) -> Color {
        Color(uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                switch level {
                case .okay: return UIColor(red: 0.40, green: 0.90, blue: 0.53, alpha: 1)
                case .caution: return UIColor(red: 1, green: 0.76, blue: 0.32, alpha: 1)
                case .avoid: return UIColor(red: 1, green: 0.49, blue: 0.49, alpha: 1)
                }
            }
            switch level {
            case .okay: return UIColor(red: 0.04, green: 0.43, blue: 0.16, alpha: 1)
            case .caution: return UIColor(red: 0.57, green: 0.29, blue: 0.01, alpha: 1)
            case .avoid: return UIColor(red: 0.74, green: 0.08, blue: 0.13, alpha: 1)
            }
        })
    }

    static func color(_ level: RecommendationLevel) -> Color {
        switch level {
        case .okay: .green
        case .caution: .orange
        case .avoid: .red
        }
    }
}

struct RecommendationHeroView: View {
    let recommendation: RecommendationPresentation
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var statusSize = 44

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                answer.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 12) {
                    jacket.frame(maxWidth: 120)
                    answer.frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 150)
            }
        }
        .padding(16)
        .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: HomeStyle.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: HomeStyle.cardRadius)
                .strokeBorder(.primary.opacity(0.04))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Leather Jacket, today: \(recommendation.title). \(recommendation.reason)")
        .accessibilityIdentifier("recommendation-hero")
    }

    private var jacket: some View {
        Image("LeatherJacket")
            .resizable()
            .scaledToFit()
            .shadow(color: .black.opacity(0.15), radius: 6, y: 6)
            .accessibilityHidden(true)
    }

    private var answer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if typeSize.isAccessibilitySize {
                    jacket.frame(width: 56, height: 70)
                }
                Text("Leather Jacket")
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)
            }
            status
            reason
        }
    }

    private var reason: some View {
        Text(recommendation.reason)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("recommendation-reason")
    }

    private var status: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 7) {
                Image(systemName: recommendation.symbolName)
                Text(recommendation.title)
            }
            .fixedSize()
            Text(recommendation.title)
                .font(.system(size: statusSize * 0.72, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .font(.system(size: statusSize, weight: .bold, design: .rounded))
        .foregroundStyle(HomeStyle.ink(recommendation.level))
        .padding(.top, 2)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct HomeIntroductionCard: View {
    let onGotIt: () -> Void
    var explanation = "The main result covers today. Dayparts show when it changes, and the reason explains why."

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("How it works")
                    .font(.headline)
                Spacer()
                Button("Got it", action: onGotIt)
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("home-introduction-got-it")
            }
            Text(explanation)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: HomeStyle.cardRadius))
    }
}

struct DayPartCardView: View {
    let dayPart: FixedDayPartPresentation
    var isOverview = false

    var body: some View {
        VStack(spacing: isOverview ? 3 : 6) {
            Image(systemName: dayPart.symbolName)
                .font(isOverview ? .subheadline.weight(.light) : .title3.weight(.light))
                .foregroundStyle(.secondary)
                .opacity(detailOpacity)
                .accessibilityHidden(true)
            Text(dayPart.label)
                .font(isOverview ? .caption.weight(.medium) : .subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .frame(maxWidth: .infinity)
                .opacity(detailOpacity)
            Text(dayPart.timeRangeLabel)
                .font(isOverview ? .caption2.monospacedDigit() : .caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .opacity(detailOpacity)
            status
        }
        .padding(.horizontal, 6)
        .padding(.vertical, isOverview ? 6 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(HomeStyle.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(statusColor.opacity(dayPart.isPast ? 0.04 : 0.09))
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayPart.accessibilityLabel)
    }

    private var status: some View {
        Text(dayPart.statusTitle)
            .font(.subheadline.bold())
            .lineLimit(1)
            .foregroundStyle(statusInk)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(statusColor.opacity(dayPart.isPast ? 0.08 : 0.16), in: Capsule())
    }

    private var statusInk: Color {
        HomeStyle.ink(dayPart.tone)
    }

    private var statusColor: Color {
        if dayPart.item == .leatherJacket {
            return dayPart.recommendation.map { HomeStyle.color($0.level) } ?? .secondary
        }
        switch dayPart.itemSummaryLevel {
        case .yes: return .green
        case .maybe: return .orange
        case .no: return .red
        case nil: return .secondary
        }
    }

    private var detailOpacity: Double {
        dayPart.isPast ? 0.48 : 1
    }
}

struct DayPartsView: View {
    let dayParts: [FixedDayPartPresentation]
    var isOverview = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 120
    @ScaledMetric(relativeTo: .body) private var overviewRowHeight: CGFloat = 100

    private let columnSpacing: CGFloat = 8

    @ViewBuilder
    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    cards
                }
            } else {
                GeometryReader { geometry in
                    let cardWidth = max(
                        0,
                        (geometry.size.width - CGFloat(dayParts.count - 1) * columnSpacing)
                            / CGFloat(max(1, dayParts.count))
                    )
                    HStack(spacing: columnSpacing) {
                        ForEach(Array(dayParts.enumerated()), id: \.element.id) { index, dayPart in
                            DayPartCardView(dayPart: dayPart, isOverview: isOverview)
                                .frame(width: cardWidth)
                                .accessibilityIdentifier("period-\(index)")
                        }
                    }
                }
                .frame(height: isOverview ? overviewRowHeight : rowHeight)
            }
        }
    }

    private var cards: some View {
        ForEach(Array(dayParts.enumerated()), id: \.element.id) { index, dayPart in
            DayPartCardView(dayPart: dayPart, isOverview: isOverview)
                .accessibilityIdentifier("period-\(index)")
        }
    }
}

struct HourlySuitabilityView: View {
    let presentation: DailyRecommendationPresentation

    var body: some View {
        HourlyTimelineView(
            hours: presentation.displayHours.map(HourlyTimelineSegment.init),
            title: "Hourly suitability", identifier: "hourly-timeline",
            hasConsolidatedDifferences: presentation.hasConsolidatedDifferences
        )
    }
}

struct HourlyTimelineView: View {
    let hours: [HourlyTimelineSegment]
    let title: String
    let identifier: String
    var hasConsolidatedDifferences = false
    var showsUsefulnessExplanation = false
    @ScaledMetric(relativeTo: .caption) private var axisHeight = 20
    @ScaledMetric(relativeTo: .caption) private var segmentHeight = 24

    private var hasRepeatedLocalHour: Bool { Set(hours.map(\.timeLabel)).count != hours.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(identifier)

            GeometryReader { geometry in
                let count = hours.count
                let hoursPerDayPart = 6
                let hourSpacing: CGFloat = 2
                let dayPartSpacing: CGFloat = 8
                Group {
                    if count == FixedDayPart.allCases.count * hoursPerDayPart {
                        let internalGapCount = count - FixedDayPart.allCases.count
                        let width = (
                            geometry.size.width
                                - CGFloat(internalGapCount) * hourSpacing
                                - CGFloat(FixedDayPart.allCases.count - 1) * dayPartSpacing
                        ) / CGFloat(count)
                        HStack(alignment: .top, spacing: dayPartSpacing) {
                            ForEach(FixedDayPart.allCases.indices, id: \.self) { dayPartIndex in
                                HStack(alignment: .top, spacing: hourSpacing) {
                                    ForEach(0..<hoursPerDayPart, id: \.self) { offset in
                                        let index = dayPartIndex * hoursPerDayPart + offset
                                        segment(
                                            hours[index],
                                            index: index,
                                            width: width
                                        )
                                    }
                                }
                            }
                        }
                    } else {
                        let width = (
                            geometry.size.width - CGFloat(max(0, count - 1)) * hourSpacing
                        ) / CGFloat(max(1, count))
                        HStack(alignment: .top, spacing: hourSpacing) {
                            ForEach(Array(hours.enumerated()), id: \.element.id) { index, hour in
                                segment(hour, index: index, width: width)
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
            }
            .frame(height: segmentHeight + axisHeight + 12)
            if hours.contains(where: \.isInferred) {
                Text("? Forecast uncertain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if hasConsolidatedDifferences {
                Text("Hourly conditions shown; period advice groups brief changes for safety.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("hourly-grouping-note")
            }
            if showsUsefulnessExplanation {
                Text("YES: useful · MAYBE: borderline · NO: not needed. A daypart is YES if any hour is useful.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func segment(_ hour: HourlyTimelineSegment, index: Int, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(segmentColor(hour))
                .overlay {
                    if hour.isInferred {
                        Image(systemName: "questionmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(height: segmentHeight)

            Color.clear.frame(height: axisHeight)
                .overlay(alignment: index >= hours.count - 2 ? .topTrailing : .topLeading) {
                    if hasRepeatedLocalHour || index % 3 == 0 {
                        Text(
                            hasRepeatedLocalHour
                                ? hour.unambiguousAxisTimeLabel
                                : hour.axisTimeLabel
                        )
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }
        }
        .frame(width: width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hour.accessibilityLabel)
        .accessibilityIdentifier("\(showsUsefulnessExplanation ? "item-hour" : "hour")-\(index)")
    }

    private func segmentColor(_ hour: HourlyTimelineSegment) -> Color {
        if hour.isInferred { return Color.secondary.opacity(0.15) }
        let color: Color
        switch hour.tone {
        case .positive: color = .green
        case .caution: color = .orange
        case .negative: color = .red
        case .neutral: color = .secondary
        }
        return color.opacity(hour.isPast ? 0.22 : 0.62)
    }
}
