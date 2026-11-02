import SwiftUI

extension HomeStyle {
    private static let unavailableDayPartInk = Color(uiColor: UIColor { traits in
        UIColor(white: traits.userInterfaceStyle == .dark ? 0.60 : 0.38, alpha: 1)
    })

    static let finishedDayPartInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 190 / 255.0, green: 190 / 255.0, blue: 194 / 255.0, alpha: 1)
            : UIColor(white: 0.38, alpha: 1)
    })

    static func dayPartFill(_ tone: ItemAdviceTone, isPast: Bool) -> Color {
        Color(uiColor: UIColor { traits in
            if isPast {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 50 / 255.0, green: 50 / 255.0, blue: 54 / 255.0, alpha: 1)
                    : UIColor(white: 0.93, alpha: 1)
            }
            if traits.userInterfaceStyle == .dark {
                switch tone {
                case .positive: return UIColor(red: 0.10, green: 0.18, blue: 0.13, alpha: 1)
                case .caution: return UIColor(red: 0.19, green: 0.15, blue: 0.09, alpha: 1)
                case .negative: return UIColor(red: 0.20, green: 0.12, blue: 0.13, alpha: 1)
                case .neutral: return .secondarySystemGroupedBackground
                }
            }
            switch tone {
            case .positive: return UIColor(red: 0.92, green: 0.96, blue: 0.93, alpha: 1)
            case .caution: return UIColor(red: 0.99, green: 0.96, blue: 0.90, alpha: 1)
            case .negative: return UIColor(red: 0.99, green: 0.93, blue: 0.94, alpha: 1)
            case .neutral: return .secondarySystemGroupedBackground
            }
        })
    }

    static func dayPartBadgeFill(_ tone: ItemAdviceTone, isPast: Bool) -> Color {
        Color(uiColor: UIColor { traits in
            if isPast {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 65 / 255.0, green: 65 / 255.0, blue: 70 / 255.0, alpha: 1)
                    : UIColor(white: 0.87, alpha: 1)
            }
            if traits.userInterfaceStyle == .dark {
                switch tone {
                case .positive: return UIColor(red: 0.12, green: 0.27, blue: 0.18, alpha: 1)
                case .caution: return UIColor(red: 0.31, green: 0.22, blue: 0.09, alpha: 1)
                case .negative: return UIColor(red: 0.31, green: 0.13, blue: 0.14, alpha: 1)
                case .neutral: return UIColor(white: 0.14, alpha: 1)
                }
            }
            switch tone {
            case .positive: return UIColor(red: 0.83, green: 0.92, blue: 0.86, alpha: 1)
            case .caution: return UIColor(red: 0.97, green: 0.89, blue: 0.74, alpha: 1)
            case .negative: return UIColor(red: 0.97, green: 0.84, blue: 0.86, alpha: 1)
            case .neutral: return .systemGroupedBackground
            }
        })
    }

    static func dayPartInk(_ tone: ItemAdviceTone, isPast: Bool) -> Color {
        if isPast { return finishedDayPartInk }
        return tone == .neutral ? unavailableDayPartInk : ink(tone)
    }

    static func ink(_ tone: ItemAdviceTone) -> Color {
        switch tone {
        case .positive: ink(RecommendationLevel.okay)
        case .caution: ink(RecommendationLevel.caution)
        case .negative: ink(RecommendationLevel.avoid)
        case .neutral: .secondary
        }
    }

    static func symbol(_ tone: ItemAdviceTone) -> String {
        switch tone {
        case .positive: "checkmark.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .negative: "xmark.circle.fill"
        case .neutral: "minus.circle"
        }
    }
}

struct ItemArtwork: View {
    let item: PredefinedItem
    var symbolInset: CGFloat = 8

    var body: some View {
        Group {
            if item == .leatherJacket {
                Image("LeatherJacket").resizable().scaledToFit()
            } else {
                Image(systemName: item.symbolName)
                    .resizable().scaledToFit().padding(symbolInset).foregroundStyle(.secondary)
            }
        }
        .accessibilityHidden(true)
    }
}

struct ItemSelectionView: View {
    let isEditing: Bool
    let onSave: (Set<PredefinedItem>) -> Void
    var onCancel: (() -> Void)?
    @State private var draft: Set<PredefinedItem>

    init(
        selected: [PredefinedItem], isEditing: Bool,
        onSave: @escaping (Set<PredefinedItem>) -> Void, onCancel: (() -> Void)? = nil
    ) {
        self.isEditing = isEditing
        self.onSave = onSave
        self.onCancel = onCancel
        _draft = State(initialValue: Set(selected))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("What would you like weather advice for?")
                        .foregroundStyle(.secondary)
                    VStack(spacing: 0) {
                        ForEach(PredefinedItem.allCases, id: \.self) { item in
                            Button {
                                if draft.contains(item) { draft.remove(item) } else { draft.insert(item) }
                            } label: {
                                HStack(spacing: 14) {
                                    ItemArtwork(item: item, symbolInset: 0)
                                        .frame(width: 24, height: 28)
                                        .frame(width: 36, height: 36)
                                    Text(item.name).font(.headline).multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 8)
                                    Image(systemName: draft.contains(item) ? "checkmark.circle.fill" : "circle")
                                        .font(.title2).foregroundStyle(draft.contains(item) ? Color.accentColor : .secondary)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .frame(minHeight: 52).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.name)
                            .accessibilityValue(draft.contains(item) ? "Selected" : "Not selected")
                            .accessibilityIdentifier("select-item-\(item.rawValue)")
                            if item != PredefinedItem.allCases.last { Divider().padding(.leading, 62) }
                        }
                    }
                    .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: HomeStyle.cardRadius))
                    Text("Change items using the gear at the bottom of Home.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(16).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .background(HomeStyle.background)
            .navigationTitle("Choose your items")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if let onCancel {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Text(draft.isEmpty ? "Select at least one item" : "\(draft.count) selected")
                        .font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("selection-count")
                    Button { onSave(draft) } label: {
                        Text(isEditing ? "Save selection" : "Continue").frame(maxWidth: .infinity)
                    }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(draft.isEmpty)
                        .accessibilityIdentifier("confirm-item-selection")
                }
                .padding(16).frame(maxWidth: .infinity).background(HomeStyle.background)
            }
        }
    }
}

struct ItemSummaryView: View {
    let presentation: ItemHomePresentation
    let dayParts: [FixedDayPartPresentation]
    var overviewLayout: ItemOverviewLayout?
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var statusSize = 44
    @ScaledMetric(relativeTo: .title) private var overviewStatusSize = 32

    private var isOverview: Bool { overviewLayout != nil }
    private var isGallery: Bool { overviewLayout == .gallery }

    var qualifier: String? { presentation.heroQualifier(dayParts: dayParts) }
    var heroAccessibilityLabel: String { presentation.heroAccessibilityLabel(qualifier: qualifier) }

    var body: some View {
        Group {
            if isGallery {
                VStack(alignment: .leading, spacing: 8) {
                    overviewArtwork.frame(height: 80)
                    copy
                }
            } else {
                horizontalHero
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(heroAccessibilityLabel)
    }

    private var horizontalHero: some View {
        HStack(spacing: isOverview ? 12 : 16) {
            if !typeSize.isAccessibilitySize {
                if isOverview {
                    overviewArtwork.frame(width: 96, height: 96)
                } else {
                    ItemArtwork(item: presentation.id).frame(width: 112, height: 144)
                }
            }
            copy
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var overviewArtwork: some View {
        ItemArtwork(item: presentation.id)
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: isOverview ? 4 : 8) {
            HStack(spacing: 10) {
                if typeSize.isAccessibilitySize && !isGallery {
                    ItemArtwork(item: presentation.id).frame(width: 56, height: 70)
                }
                Text(presentation.id.name).font(isOverview ? .headline : .title3.bold())
            }
            heroStatus
            if let qualifier {
                Text(qualifier).font((isOverview ? Font.footnote : .caption).weight(.semibold).monospacedDigit())
            }
            Text(presentation.explanation).font(.subheadline).foregroundStyle(.secondary)
                .accessibilityIdentifier("item-explanation")
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var heroStatus: some View {
        if let title = presentation.heroTitle {
            if isOverview {
                // The short answer keeps its full text size; omit the redundant symbol in tight tiles.
                Text(title)
                    .font(.system(size: answerSize, weight: .bold, design: .rounded))
                    .foregroundStyle(HomeStyle.ink(presentation.tone))
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 7) {
                        Image(systemName: HomeStyle.symbol(presentation.tone)).accessibilityHidden(true)
                        Text(title)
                    }
                    .fixedSize()
                    Text(title).font(.system(size: answerSize * 0.72, weight: .bold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.65)
                }
                .font(.system(size: answerSize, weight: .bold, design: .rounded))
                .foregroundStyle(HomeStyle.ink(presentation.tone))
            }
        } else {
            Text(presentation.title).font(.title2.bold()).foregroundStyle(.secondary)
        }
    }

    private var answerSize: CGFloat { isOverview ? overviewStatusSize : statusSize }

}

struct ItemHourlyAdviceView: View {
    let evaluation: ItemDailyEvaluation
    var currentTime: Date?

    var body: some View {
        HourlyTimelineView(
            hours: evaluation.hours.map {
                HourlyTimelineSegment($0, item: evaluation.item, timezone: evaluation.timezoneIdentifier, currentTime: currentTime)
            },
            title: "Hourly suitability", identifier: "item-hourly-timeline", showsUsefulnessExplanation: true
        )
    }
}
