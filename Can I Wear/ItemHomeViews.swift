import SwiftUI

extension HomeStyle {
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
                    Text("You can change these anytime using the gear on Home.")
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
    var isOverview = false
    var qualifier: String?
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var statusSize = 44
    @ScaledMetric(relativeTo: .title) private var overviewStatusSize = 32

    var body: some View {
        HStack(spacing: isOverview ? 12 : 16) {
            if !typeSize.isAccessibilitySize {
                ItemArtwork(item: presentation.id)
                    .frame(width: isOverview ? 64 : 112, height: isOverview ? 80 : 144)
            }
            VStack(alignment: .leading, spacing: isOverview ? 4 : 8) {
                HStack(spacing: 10) {
                    if typeSize.isAccessibilitySize {
                        ItemArtwork(item: presentation.id).frame(width: 56, height: 70)
                    }
                    Text(presentation.id.name).font(isOverview ? .headline : .title3.bold())
                    if isOverview {
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                heroStatus
                if let qualifier {
                    Text(qualifier).font(.caption.weight(.semibold).monospacedDigit())
                }
                Text(presentation.reason).font(isOverview ? .caption : .subheadline).foregroundStyle(.secondary)
                if let note = presentation.uncertaintyNote { Text(note).font(.caption).foregroundStyle(.secondary) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var heroStatus: some View {
        if let title = presentation.heroTitle {
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
