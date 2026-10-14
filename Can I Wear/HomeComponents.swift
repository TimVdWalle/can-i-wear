import SwiftUI

enum HomeStyle {
    static let spacing: CGFloat = 20
    static let cardRadius: CGFloat = 22
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)

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
                HStack(spacing: 14) {
                    jacket.frame(maxWidth: 150)
                    answer.frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 200)
            }
        }
        .padding(20)
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
            if typeSize.isAccessibilitySize {
                status
                reason
            } else {
                reason
                status
            }
        }
    }

    private var reason: some View {
        Text(recommendation.reason)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
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
        .padding(.top, 14)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct DayPartCardView: View {
    let dayPart: FixedDayPartPresentation

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: dayPart.symbolName)
                .font(.title2.weight(.light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(dayPart.label)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .frame(maxWidth: .infinity)
            Text(dayPart.timeRangeLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(dayPart.recommendation?.title ?? "—")
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(dayPart.recommendation.map { HomeStyle.ink($0.level) } ?? .secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(statusColor.opacity(0.16), in: Capsule())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(HomeStyle.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(statusColor.opacity(0.09))
                }
        }
        .saturation(dayPart.isPast ? 0 : 1)
        .opacity(dayPart.isPast ? 0.48 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayPart.accessibilityLabel)
    }

    private var statusColor: Color {
        dayPart.recommendation.map { HomeStyle.color($0.level) } ?? .secondary
    }
}

struct DayPartsView: View {
    let dayParts: [FixedDayPartPresentation]
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var rowHeight = 146

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
                            DayPartCardView(dayPart: dayPart)
                                .frame(width: cardWidth)
                                .accessibilityIdentifier("period-\(index)")
                        }
                    }
                }
                .frame(height: rowHeight)
            }
        }
        .accessibilityIdentifier("day-parts")
    }

    private var cards: some View {
        ForEach(Array(dayParts.enumerated()), id: \.element.id) { index, dayPart in
            DayPartCardView(dayPart: dayPart)
                .accessibilityIdentifier("period-\(index)")
        }
    }
}

struct HourlySuitabilityView: View {
    let presentation: DailyRecommendationPresentation
    @ScaledMetric(relativeTo: .caption) private var axisHeight = 24
    @ScaledMetric(relativeTo: .caption) private var segmentHeight = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hourly suitability")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)

            GeometryReader { geometry in
                let count = presentation.displayHours.count
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
                                            presentation.displayHours[index],
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
                            ForEach(Array(presentation.displayHours.enumerated()), id: \.element.id) { index, hour in
                                segment(hour, index: index, width: width)
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
            }
            .frame(height: segmentHeight + axisHeight + 12)
            .accessibilityIdentifier("hourly-timeline")

            if presentation.hasInferredHour {
                Text("? Forecast uncertain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if presentation.hasConsolidatedDifferences {
                Text("Hourly conditions shown; period advice groups brief changes for safety.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("hourly-grouping-note")
            }
        }
    }

    private func segment(_ hour: HourlySuitabilityPresentation, index: Int, width: CGFloat) -> some View {
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
                .overlay(alignment: index >= presentation.displayHours.count - 2 ? .topTrailing : .topLeading) {
                    if presentation.hasRepeatedLocalHour || index % 3 == 0 {
                        Text(
                            presentation.hasRepeatedLocalHour
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
        .accessibilityIdentifier("hour-\(index)")
    }

    private func segmentColor(_ hour: HourlySuitabilityPresentation) -> Color {
        if hour.isInferred { return Color.secondary.opacity(0.15) }
        if hour.isPast { return HomeStyle.color(hour.recommendation.level).opacity(0.22) }
        return HomeStyle.color(hour.recommendation.level).opacity(0.62)
    }
}
