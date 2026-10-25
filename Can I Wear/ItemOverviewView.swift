import SwiftUI

nonisolated enum ItemOverviewLayout {
    case miniHeroes
    case gallery
}

/// D-075: count chooses the design; available space only changes its column count.
struct ItemOverviewView: View {
    let items: [ItemHomePresentation]
    let dayParts: (PredefinedItem) -> [FixedDayPartPresentation]
    let missingPlanningContext: (PredefinedItem) -> Bool
    let onSelect: (PredefinedItem) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var width: CGFloat = 0

    private var layout: ItemOverviewLayout { items.count >= 4 ? .gallery : .miniHeroes }
    private var columns: Int { layout == .gallery && width >= 350 && typeSize <= .large ? 2 : 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    heading
                    Spacer(minLength: 8)
                    hint
                }
                VStack(alignment: .leading, spacing: 4) { heading; hint }
            }
            if layout == .gallery && columns == 2 { daypartKey }
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(0..<((items.count + columns - 1) / columns), id: \.self) { row in
                    GridRow(alignment: .top) {
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            if index < items.count {
                                card(items[index])
                            } else {
                                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                            }
                        }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    private var heading: some View {
        Text("Your items today").font(.headline).accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(layout == .gallery ? "item-gallery" : "item-mini-heroes")
    }

    private var hint: some View {
        Text("Tap an item for detail").font(.footnote).foregroundStyle(.secondary)
    }

    private var daypartKey: some View {
        HStack(spacing: 4) {
            ForEach(FixedDayPart.allCases, id: \.self) { part in
                VStack(spacing: 2) {
                    Text(part.label).fontWeight(.medium)
                    Text(part.timeRangeLabel).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .font(.footnote)
        .accessibilityElement(children: .combine)
    }

    private func card(_ item: ItemHomePresentation) -> some View {
        let parts = dayParts(item.id)
        let planningNote = item.evaluation != nil && missingPlanningContext(item.id)
            ? "Earlier periods unavailable in this forecast." : nil
        return Button { onSelect(item.id) } label: {
            VStack(alignment: .leading, spacing: 6) {
                ItemSummaryView(presentation: item, overviewLayout: layout, qualifier: item.heroQualifier(dayParts: parts))
                if layout == .gallery { Spacer(minLength: 0) }
                if item.evaluation != nil {
                    OverviewDayPartsView(dayParts: parts, isGallery: layout == .gallery, showsRanges: columns == 1)
                    if let planningNote {
                        Text(planningNote)
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: HomeStyle.cardRadius))
            .contentShape(RoundedRectangle(cornerRadius: HomeStyle.cardRadius))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([item.overviewAccessibilityLabel(dayParts: parts), planningNote].compactMap { $0 }.joined(separator: " "))
        }
        .buttonStyle(.plain)
        .accessibilityHint("View periods and hourly details")
        .accessibilityIdentifier("item-card-\(item.id.rawValue)")
    }
}

private struct OverviewDayPartsView: View {
    let dayParts: [FixedDayPartPresentation]
    let isGallery: Bool
    let showsRanges: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 6) { cards }
        } else {
            HStack(spacing: isGallery ? 2 : 5) { cards }
        }
    }

    private var cards: some View {
        ForEach(Array(dayParts.enumerated()), id: \.element.id) { index, part in
            VStack(spacing: 2) {
                Text(isGallery && !showsRanges ? compactLabel(part.dayPart) : part.label)
                    .font(.footnote.weight(.medium))
                    .opacity(part.isPast ? 0.48 : 1)
                if showsRanges {
                    Text(part.timeRangeLabel).font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary).opacity(part.isPast ? 0.48 : 1)
                }
                Text(part.statusTitle).font(.footnote.bold()).foregroundStyle(HomeStyle.ink(part.tone))
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(HomeStyle.ink(part.tone).opacity(part.isPast ? 0.04 : 0.09), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(part.accessibilityLabel)
            .accessibilityIdentifier("period-\(index)")
        }
    }

    private func compactLabel(_ part: FixedDayPart) -> String {
        switch part {
        case .morning: "Morn."
        case .afternoon: "Aft."
        case .evening: "Eve."
        }
    }
}
