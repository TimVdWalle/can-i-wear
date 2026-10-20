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
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if !typeSize.isAccessibilitySize {
                ItemArtwork(item: presentation.id).frame(width: isOverview ? 48 : 80, height: isOverview ? 60 : 110)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(presentation.id.name).font(isOverview ? .headline : .title3.bold())
                Label(presentation.title, systemImage: HomeStyle.symbol(presentation.tone))
                    .font(.title2.bold()).foregroundStyle(HomeStyle.ink(presentation.tone))
                Text(presentation.timing).font(.subheadline.weight(.semibold).monospacedDigit())
                Text(presentation.reason).font(.subheadline).foregroundStyle(.secondary)
                if let note = presentation.uncertaintyNote { Text(note).font(.caption).foregroundStyle(.secondary) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            if isOverview {
                Image(systemName: "chevron.right").foregroundStyle(.tertiary).accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ItemPeriodsView: View {
    let evaluation: ItemDailyEvaluation
    @Environment(\.dynamicTypeSize) private var typeSize

    private var columns: [GridItem] {
        typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 128))]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(Array(evaluation.periods.enumerated()), id: \.offset) { index, period in
                let title = ItemHomePresentation.levelTitle(period.level, item: evaluation.item, inferred: period.isInferred)
                let tone = ItemHomePresentation.tone(period.level, item: evaluation.item, inferred: period.isInferred)
                let range = ItemHomePresentation.range(period.interval, timezone: period.timezoneIdentifier)
                VStack(spacing: 6) {
                    Text(range).font(.caption.monospacedDigit()).fixedSize(horizontal: false, vertical: true)
                    Label(title, systemImage: period.isInferred ? "questionmark.circle" : HomeStyle.symbol(tone))
                        .font(.caption.bold())
                }
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(HomeStyle.ink(tone))
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(8)
                .background(HomeStyle.ink(tone).opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(range), \(title). \(period.reasons.map(ItemHomePresentation.reasonText).joined(separator: " "))")
                .accessibilityIdentifier("item-period-\(evaluation.item.rawValue)-\(index)")
            }
        }
    }
}

struct ItemHourlyAdviceView: View {
    let evaluation: ItemDailyEvaluation

    private var hasRepeatedLocalHour: Bool {
        Set(evaluation.hours.map { HomeTime.label($0.timestamp, timezone: evaluation.timezoneIdentifier) }).count != evaluation.hours.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hourly advice").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("item-hourly-timeline")
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(Array(evaluation.hours.enumerated()), id: \.element.timestamp) { index, hour in
                        let tone = ItemHomePresentation.tone(hour.advice.level, item: evaluation.item, inferred: hour.isInferred)
                        let title = ItemHomePresentation.levelTitle(hour.advice.level, item: evaluation.item, inferred: hour.isInferred)
                        VStack(spacing: 6) {
                            Text(HomeTime.label(hour.timestamp, timezone: evaluation.timezoneIdentifier, offset: hasRepeatedLocalHour))
                                .monospacedDigit()
                            Image(systemName: hour.isInferred ? "questionmark.circle" : HomeStyle.symbol(tone))
                            Text(title)
                        }
                        .font(.caption).foregroundStyle(HomeStyle.ink(tone)).padding(10)
                        .frame(minWidth: 70, minHeight: 70)
                        .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(HomeTime.label(hour.timestamp, timezone: evaluation.timezoneIdentifier, offset: true)), \(title). \(ItemHomePresentation.reasonText(hour.advice.reason))")
                        .accessibilityIdentifier("item-hour-\(index)")
                    }
                }
            }
            Text("Consecutive hours with the same advice are grouped; short useful intervals stay visible.")
                .font(.caption).foregroundStyle(.secondary)
            if evaluation.hours.contains(where: \.isInferred) {
                Text("? Forecast uncertain — missing weather data, not observed conditions.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
