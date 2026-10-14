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
    let period: PeriodPresentation
    let visibleCardCount: Int
    @ScaledMetric(relativeTo: .caption) private var minimumCardWidth = 80

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: period.symbolName)
                .font(.title2.weight(.light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(period.compactLabel)
                .font(.subheadline.weight(.medium).monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
            Text(period.recommendation.title)
                .font(.caption.bold())
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(HomeStyle.ink(period.recommendation.level))
                .padding(.horizontal, 4)
                .padding(.vertical, 7)
                .background(HomeStyle.color(period.recommendation.level).opacity(0.16), in: Capsule())
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 18)
        .containerRelativeFrame(.horizontal, count: visibleCardCount, spacing: 8)
        .frame(minWidth: minimumCardWidth, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(HomeStyle.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(HomeStyle.color(period.recommendation.level).opacity(0.07))
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(period.label), \(period.recommendation.title)")
    }
}

struct DayPartsView: View {
    let periods: [PeriodPresentation]
    @Environment(\.dynamicTypeSize) private var typeSize

    private var visibleCardCount: Int {
        if typeSize.isAccessibilitySize { return 1 }
        return min(max(2, periods.count), typeSize > .large ? 2 : 4)
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(periods.enumerated()), id: \.element.interval.start) { index, period in
                    DayPartCardView(period: period, visibleCardCount: visibleCardCount)
                        .accessibilityIdentifier("period-\(index)")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("day-parts")
    }
}

struct HourlySuitabilityView: View {
    let presentation: DailyRecommendationPresentation
    @ScaledMetric(relativeTo: .caption) private var minimumSegmentWidth = 16
    @ScaledMetric(relativeTo: .caption) private var axisHeight = 24
    @ScaledMetric(relativeTo: .caption) private var segmentHeight = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hourly suitability")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)

            GeometryReader { geometry in
                let count = presentation.hours.count
                let width = max(
                    presentation.hasRepeatedLocalHour ? minimumSegmentWidth * 7 : minimumSegmentWidth,
                    (geometry.size.width - CGFloat(max(0, count - 1)) * 3) / CGFloat(max(1, count))
                )
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 3) {
                        ForEach(Array(presentation.hours.enumerated()), id: \.element.id) { index, hour in
                            segment(hour, index: index, width: width)
                        }
                    }
                    .padding(.bottom, 4)
                }
                .scrollIndicators(.hidden)
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
                .fill(hour.isInferred ? Color.secondary.opacity(0.15) : HomeStyle.color(hour.recommendation.level).opacity(0.55))
                .overlay {
                    Image(systemName: hour.isInferred ? "questionmark" : hour.recommendation.segmentSymbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .frame(height: segmentHeight)

            Color.clear.frame(height: axisHeight)
                .overlay(alignment: index >= presentation.hours.count - 2 ? .topTrailing : .topLeading) {
                    if presentation.hasRepeatedLocalHour || index % 3 == 0 {
                        Text(presentation.hasRepeatedLocalHour ? hour.unambiguousTimeLabel : hour.timeLabel)
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
}
