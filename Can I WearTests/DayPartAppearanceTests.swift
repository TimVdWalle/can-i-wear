import SwiftUI
import Testing
import UIKit
@testable import Can_I_Wear

@MainActor
struct DayPartAppearanceTests {
    @Test func artworkHasNoSeparateBackgroundForAnyAnswerOrAccessibilityLayout() throws {
        for scheme in [ColorScheme.light, .dark] {
            let expected = try pixels(render(HomeStyle.card, scheme: scheme, width: 1, height: 1))[0]
            for layout in [ItemOverviewLayout?.none, .miniHeroes, .gallery] {
                for level in [ItemAdviceLevel?.some(.yes), .some(.maybe), .some(.no), .none] {
                    let display: ItemHomePresentation
                    let parts: [FixedDayPartPresentation]
                    if let level {
                        (display, parts) = try fixture(Array(repeating: level, count: 18), item: .sunglasses)
                    } else {
                        display = ItemHomePresentation(result: ItemForecastResult(item: .sunglasses, evaluation: nil))
                        parts = []
                    }
                    for size in [DynamicTypeSize.large, .accessibility3] {
                        let image = try render(ItemSummaryView(presentation: display, dayParts: parts, overviewLayout: layout),
                                               scheme: scheme, width: 358, height: 420, typeSize: size)
                        let colors = try pixels(image)
                        let sample = colors[12 * 358 + 8]
                        #expect(sample == expected, "\(String(describing: layout)) \(scheme) \(size) \(String(describing: level)) artwork background")
                    }
                }
            }
        }
    }

    @Test func daypartsBecomeFinishedOnlyAtTheirExactEndBoundary() throws {
        for item in PredefinedItem.allCases {
            let (_, beforeNoon) = try fixture(Array(repeating: .yes, count: 18), item: item, currentOffset: 6 - 1 / 3_600.0)
            let (_, noon) = try fixture(Array(repeating: .yes, count: 18), item: item, currentOffset: 6)
            let (_, beforeEvening) = try fixture(Array(repeating: .yes, count: 18), item: item, currentOffset: 12 - 1 / 3_600.0)
            let (_, evening) = try fixture(Array(repeating: .yes, count: 18), item: item, currentOffset: 12)
            #expect(beforeNoon.map(\.isPast) == [false, false, false])
            #expect(noon.map(\.isPast) == [true, false, false])
            #expect(beforeEvening.map(\.isPast) == [true, false, false])
            #expect(evening.map(\.isPast) == [true, true, false])
        }
    }

    @Test func activeDaypartsUseSoftCardsAndDistinctStrongerStatusPills() throws {
        for scheme in [ColorScheme.light, .dark] {
            for item in PredefinedItem.allCases {
                for level in [ItemAdviceLevel.yes, .maybe, .no] {
                    let (_, parts) = try fixture(Array(repeating: level, count: 18), item: item)
                    let image = try render(DayPartCardView(dayPart: parts[0]), scheme: scheme)
                    let sample = try pixels(image)[24 * 110 + 8]
                    let card = try pixels(render(HomeStyle.dayPartFill(parts[0].tone, isPast: false), scheme: scheme, width: 1, height: 1))[0]
                    let badge = try pixels(render(HomeStyle.dayPartBadgeFill(parts[0].tone, isPast: false), scheme: scheme, width: 1, height: 1))[0]
                    #expect(sample == card)
                    let cardChroma = max(card.red, card.green, card.blue) - min(card.red, card.green, card.blue)
                    let badgeChroma = max(badge.red, badge.green, badge.blue) - min(badge.red, badge.green, badge.blue)
                    #expect(cardChroma >= 10 && cardChroma <= 32, "Soft, visibly tinted \(scheme) \(level) card")
                    #expect(badgeChroma > cardChroma, "Stronger color belongs in the \(scheme) \(level) status pill")
                }
            }
        }
    }

    @Test func activeAndFinishedBadgeTextRetainsReadableContrast() throws {
        for scheme in [ColorScheme.light, .dark] {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                for tone in [ItemAdviceTone.positive, .caution, .negative, .neutral] {
                    for past in [false, true] {
                        let foreground = resolvedPixel(HomeStyle.dayPartInk(tone, isPast: past), scheme: scheme, contrast: contrast)
                        let background = resolvedPixel(HomeStyle.dayPartBadgeFill(tone, isPast: past), scheme: scheme, contrast: contrast)
                        let light = max(luminance(foreground), luminance(background))
                        let dark = min(luminance(foreground), luminance(background))
                        #expect((light + 0.05) / (dark + 0.05) >= 4.5, "\(scheme) \(tone), past=\(past) badge contrast")
                    }
                }
            }
        }
    }

    @Test func finishedDarkPaletteMatchesApprovedGrayWithoutRecoloringUnavailableAdvice() {
        let card = resolvedPixel(HomeStyle.dayPartFill(.positive, isPast: true), scheme: .dark, contrast: .normal)
        let badge = resolvedPixel(HomeStyle.dayPartBadgeFill(.positive, isPast: true), scheme: .dark, contrast: .normal)
        let ink = resolvedPixel(HomeStyle.dayPartInk(.positive, isPast: true), scheme: .dark, contrast: .normal)
        #expect(card == (50, 50, 54))
        #expect(badge == (65, 65, 70))
        #expect(ink == (190, 190, 194))
        let unavailable = resolvedPixel(HomeStyle.dayPartInk(.neutral, isPast: false), scheme: .dark, contrast: .normal)
        #expect(unavailable == (153, 153, 153), "Unavailable advice retains its existing ink")
        let light = resolvedPixel(HomeStyle.dayPartFill(.positive, isPast: true), scheme: .light, contrast: .normal)
        #expect(light == (237, 237, 237), "Light appearance is unchanged")
    }

    @Test func overviewDaypartsHaveRoomForLabelsAndPaddedPills() throws {
        let (_, parts) = try fixture(Array(repeating: .maybe, count: 18), item: .sunglasses, currentOffset: 6)
        for scheme in [ColorScheme.light, .dark] {
            for (gallery, ranges, width) in [(false, true, 334), (true, false, 149), (true, true, 334)] {
                let renderer = ImageRenderer(content:
                    OverviewDayPartsView(dayParts: parts, isGallery: gallery, showsRanges: ranges)
                        .frame(width: CGFloat(width)).fixedSize(horizontal: false, vertical: true)
                        .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, .large))
                renderer.scale = 1
                let image = try #require(renderer.uiImage)
                let expectedHeight: CGFloat = ranges ? 77 : 57
                #expect(abs(image.size.height - expectedHeight) <= 2,
                        "Room for 4pt gaps, 8pt tile padding and 3pt pill padding, without excessive growth")
            }
        }
    }

    @Test func compactDaypartsRenderTheSameCardAndPillPaletteWithApprovedPadding() throws {
        for scheme in [ColorScheme.light, .dark] {
            for isGallery in [false, true] {
                for past in [false, true] {
                    for level in [ItemAdviceLevel.yes, .maybe, .no] {
                        let (_, parts) = try fixture(Array(repeating: level, count: 18), item: .sunglasses, currentOffset: past ? 6 : 0)
                        let width = isGallery ? 149 : 334
                        let image = try render(OverviewDayPartsView(dayParts: parts, isGallery: isGallery, showsRanges: !isGallery),
                                               scheme: scheme, width: CGFloat(width), height: 110)
                        let colors = try pixels(image)
                        let card = try pixels(render(HomeStyle.dayPartFill(parts[0].tone, isPast: past), scheme: scheme, width: 1, height: 1))[0]
                        let badge = try pixels(render(HomeStyle.dayPartBadgeFill(parts[0].tone, isPast: past), scheme: scheme, width: 1, height: 1))[0]
                        #expect(colors[10 * width + 3] == card)
                        #expect((0..<95).contains { colors[$0 * width + 8] == badge }, "Compact dayparts need a distinct pill")
                        let mainCard = try pixels(render(HomeStyle.card, scheme: scheme, width: 1, height: 1))[0]
                        #expect(colors[109 * width + 8] == mainCard, "Padded rows must still retain compact natural heights")
                    }
                }
            }
        }
    }

    @Test func finishedDaypartsAreGrayWithoutChangingTheirStatusOrAccessibleMeaning() throws {
        for scheme in [ColorScheme.light, .dark] {
            for item in PredefinedItem.allCases {
                for level in [ItemAdviceLevel.yes, .maybe, .no] {
                    let (_, parts) = try fixture(Array(repeating: level, count: 18), item: item, currentOffset: 6)
                    let part = parts[0]
                    #expect(part.isPast)
                    #expect(part.statusTitle == (level == .yes ? "YES" : level == .maybe ? "MAYBE" : "NO"))
                    #expect(part.accessibilityLabel.contains("finished for today"))
                    let image = try render(DayPartCardView(dayPart: part), scheme: scheme)
                    let chroma = try pixels(image).map { max($0.red, $0.green, $0.blue) - min($0.red, $0.green, $0.blue) }.max() ?? 0
                    #expect(chroma <= 5, "\(item) \(scheme) completed dayparts retain the approved near-neutral gray palette")
                }
            }
        }
    }

    private func fixture(
        _ levels: [ItemAdviceLevel], item: PredefinedItem, currentOffset: TimeInterval = 0
    ) throws -> (ItemHomePresentation, [FixedDayPartPresentation]) {
        let forecast = ItemEngineFixtures.sequence(levels, for: item)
        let start = try #require(forecast.hours.first?.timestamp)
        let now = start.addingTimeInterval(currentOffset * 3_600)
        let engine = MultiItemRecommendationEngine()
        let planning = try #require(engine.evaluate(forecast, for: item, now: start))
        let remaining = try #require(engine.evaluate(forecast, for: item, now: now))
        let parts: [FixedDayPartPresentation]
        if item == .leatherJacket {
            let jacket = try #require(DailyRecommendationEngine().evaluateHours(forecast, now: start))
            parts = FixedDayPartPresentation.make(from: jacket, at: now)
        } else {
            parts = FixedDayPartPresentation.make(from: planning, at: now)
        }
        return (ItemHomePresentation(result: ItemForecastResult(item: item, evaluation: remaining)), parts)
    }

    private func render<V: View>(
        _ view: V, scheme: ColorScheme, width: CGFloat = 110, height: CGFloat = 120, typeSize: DynamicTypeSize = .large
    ) throws -> UIImage {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height, alignment: .topLeading)
            .background(HomeStyle.card).environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, typeSize))
        renderer.scale = 1
        return try #require(renderer.uiImage)
    }

    private func resolvedPixel(
        _ color: Color, scheme: ColorScheme, contrast: UIAccessibilityContrast
    ) -> (red: Int, green: Int, blue: Int) {
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = scheme == .dark ? .dark : .light
            traits.accessibilityContrast = contrast
        }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    private func pixels(_ image: UIImage) throws -> [(red: Int, green: Int, blue: Int)] {
        let image = try #require(image.cgImage)
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height,
                                            bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        return (0..<(image.width * image.height)).map { index in
            (Int(bytes[index * 4]), Int(bytes[index * 4 + 1]), Int(bytes[index * 4 + 2]))
        }
    }

    private func luminance(_ pixel: (red: Int, green: Int, blue: Int)) -> Double {
        let linear = [pixel.red, pixel.green, pixel.blue].map { byte -> Double in
            let value = Double(byte) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
    }
}
