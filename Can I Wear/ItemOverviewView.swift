import SwiftUI

nonisolated enum ItemOverviewLayout {
    case miniHeroes
    case gallery
}

/// D-075: count chooses the design; available space only changes its column count.
struct ItemOverviewView<Locality: View>: View {
    let items: [ItemHomePresentation]
    let dayParts: (PredefinedItem) -> [FixedDayPartPresentation]
    let missingPlanningContext: (PredefinedItem) -> Bool
    @ViewBuilder var locality: () -> Locality
    let onSelect: (PredefinedItem) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var width: CGFloat = 0

    private var layout: ItemOverviewLayout { items.count >= 4 ? .gallery : .miniHeroes }
    private var columns: Int { layout == .gallery && width >= 350 && typeSize <= .large ? 2 : 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                headingTitle.fixedSize()
                Spacer(minLength: 0)
                locality().fixedSize()
            }
            VStack(alignment: .trailing, spacing: 4) {
                headingTitle.frame(maxWidth: .infinity, alignment: .leading)
                locality().multilineTextAlignment(.trailing)
            }
        }
        // D-086: the selected reference aligns to the tiles, 12pt inside the card edge.
        .padding(.trailing, 12)
    }

    private var headingTitle: some View {
        Text("Your items today").font(.headline).accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(layout == .gallery ? "item-gallery" : "item-mini-heroes")
    }

    private func card(_ item: ItemHomePresentation) -> some View {
        let parts = dayParts(item.id)
        let planningNote = item.evaluation != nil && missingPlanningContext(item.id)
            ? "Earlier periods unavailable in this forecast." : nil
        return Button { onSelect(item.id) } label: {
            VStack(alignment: .leading, spacing: layout == .miniHeroes ? 6 : 10) {
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
            .padding(.vertical, layout == .miniHeroes ? 6 : 10)
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

struct OverviewDayPartsView: View {
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
            VStack(spacing: 4) {
                Text(isGallery && !showsRanges ? compactLabel(part.dayPart) : part.label)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(part.isPast ? HomeStyle.finishedDayPartInk : .primary)
                if showsRanges {
                    Text(part.timeRangeLabel).font(.footnote.monospacedDigit())
                        .foregroundStyle(part.isPast ? HomeStyle.finishedDayPartInk : .secondary)
                }
                Text(part.statusTitle).font(.footnote.bold())
                    .foregroundStyle(HomeStyle.dayPartInk(part.tone, isPast: part.isPast))
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity)
                    .background {
                        Capsule().fill(HomeStyle.dayPartBadgeFill(part.tone, isPast: part.isPast))
                            .padding(.horizontal, 2)
                    }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(HomeStyle.dayPartFill(part.tone, isPast: part.isPast), in: RoundedRectangle(cornerRadius: 10))
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
