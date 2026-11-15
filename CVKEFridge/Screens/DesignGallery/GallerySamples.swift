#if DEBUG
import CVKEFridgeCore
import SwiftUI

// Examples that put the components together as the screens do. They are for the comparison with the screenshots of
// the Android app. The real screens are in `Screens/`.

/// The top of Home: the greeting, the title, the card of the totals, the sample banner, the reminder offer, and the
/// batches that need attention.
struct GalleryHomeSample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "Good afternoon")
                    .font(Typography.greeting)
                    .foregroundStyle(Palette.onSurfaceVariant)
                Text(verbatim: "Your Kitchen")
                    .font(Typography.screenTitle)
                    .foregroundStyle(Palette.onSurface)
            }
            SurfaceCard(.standard, radius: Radius.extraLarge) {
                VStack(alignment: .leading, spacing: Space.s4) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(verbatim: "Total items")
                                .font(Typography.label)
                                .foregroundStyle(Palette.onSurfaceVariant)
                            Text(verbatim: "12")
                                .heroNumber()
                        }
                        Spacer(minLength: Space.s3)
                        BrandTile()
                    }
                    .padding(.horizontal, Space.s2)
                    .padding(.top, Space.s2)
                    Hairline()
                        .padding(.horizontal, Space.s2)
                    AdaptiveStack {
                        StatTile("Expiring", value: "3", kind: .expiring) {}
                        StatTile("Expired", value: "1", kind: .expired) {}
                    }
                }
            }
            SampleBanner()
            SurfaceCard {
                HStack(alignment: .top, spacing: Space.s3) {
                    IconTile(.bell, tone: .accent)
                    VStack(alignment: .leading, spacing: Space.s1) {
                        Text(verbatim: "Get a reminder before food expires")
                            .font(Typography.cardTitle)
                        Text(verbatim: "One notification a day at 9:00 AM names the food that expires soon. You can change the time in Settings.")
                            .font(Typography.secondary)
                            .foregroundStyle(Palette.onSurfaceVariant)
                        FlowLayout(alignment: .trailing, spacing: Space.s3) {
                            Button("Not now") {}
                                .buttonStyle(.quiet)
                            Button("Turn on") {}
                                .buttonStyle(.secondary(.compact))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, Space.s1)
                    }
                }
            }
            SectionHeader("Needs attention", actionTitle: "View all") {}
                .padding(.top, Space.s2)
            ScrollView(.horizontal) {
                HStack(spacing: Space.s3) {
                    AttentionCard(name: "Chicken thighs", detail: "600 g • Meat", status: "Expired yesterday", icon: .meat, freshness: .expired)
                    AttentionCard(name: "Baby spinach", detail: "200 g • Produce", status: "Expires today", icon: .produce, freshness: .expiring)
                    AttentionCard(name: "Whole milk", detail: "1 l • Dairy", status: "Expires tomorrow", icon: .dairy, freshness: .expiring)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.screenMargin)
            }
            .scrollIndicators(.hidden)
            .fadingEdges()
            .padding(.horizontal, -Space.screenMargin)
        }
    }
}

private struct AttentionCard: View {
    let name: String
    let detail: String
    let status: String
    let icon: AppIcon
    let freshness: Freshness

    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 180

    var body: some View {
        let tone: CardTone = freshness == .expired ? .expired : .expiring
        Button {} label: {
            SurfaceCard(tone) {
                VStack(alignment: .leading, spacing: Space.s1) {
                    IconTile(icon, tone: .on(tone))
                        .padding(.bottom, Space.s2)
                    Text(verbatim: name)
                        .font(Typography.cardTitle)
                        .lineLimit(2)
                    Text(verbatim: detail)
                        .font(Typography.secondary)
                    Spacer(minLength: Space.s2)
                    StatusLabel(verbatim: status, freshness: freshness, showsIcon: true, tinted: false)
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: min(width, 300))
        }
        .buttonStyle(.card)
    }
}

/// The rows of My Fridge and the card of History.
struct GalleryListSample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.cardGap) {
            FoodRow(name: "Chicken thighs", quantity: "600 g", status: "Expired yesterday, estimated", category: "Meat", icon: .meat, freshness: .expired)
            FoodRow(name: "Baby spinach", quantity: "200 g", status: "Expires today, estimated", category: "Produce", icon: .produce, freshness: .expiring)
            FoodRow(name: "Leftover lasagne with spinach", quantity: "2", status: "Expires in 3d, estimated", category: "Leftovers", icon: .leftovers, freshness: .fresh)
            FoodRow(name: "Orange juice", quantity: "1 bottle", status: "Expires in 5d", category: "Beverage", icon: .beverage, freshness: .fresh)

            SurfaceCard(.standard, radius: Radius.extraLarge, padding: Space.s5) {
                VStack(alignment: .leading, spacing: Space.s4) {
                    Text(verbatim: "Used and thrown away")
                        .font(Typography.cardTitle)
                    AdaptiveStack(verticalAlignment: .top, spacing: Space.s4) {
                        HistoryFigure(icon: .check, color: Palette.Status.fresh, value: "3", label: "batches used", detail: "6 pcs • 1 l • 1 bottle")
                        HistoryFigure(icon: .delete, color: Palette.tertiary, value: "2", label: "batches thrown away", detail: "2 pcs • 400 g")
                    }
                    Hairline()
                    Text(verbatim: "Thrown away most often")
                        .font(Typography.label)
                        .foregroundStyle(Palette.onSurfaceVariant)
                    HStack(spacing: Space.s3) {
                        IconTile(.dairy, size: 32)
                        Text(verbatim: "Greek yoghurt")
                            .font(Typography.body)
                        Spacer()
                        Text(verbatim: "1 batch")
                            .font(Typography.secondary)
                            .foregroundStyle(Palette.onSurfaceVariant)
                    }
                }
            }
            .padding(.top, Space.s4)
            SectionHeader(verbatim: "Today", style: .group)
                .padding(.top, Space.s3)
        }
    }
}

private struct FoodRow: View {
    let name: String
    let quantity: String
    let status: String
    let category: String
    let icon: AppIcon
    let freshness: Freshness

    /// "600 g • Expires in 3d": the quantity, and the days left in the colour of the freshness.
    private var line: AttributedString {
        var line = AttributedString("\(quantity) • ")
        var days = AttributedString(status)
        days.foregroundColor = freshness.color
        line.append(days)
        return line
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // With an accessibility text size, the name has two lines and the category is below the other lines.
        let large = dynamicTypeSize.isAccessibilitySize
        Button {} label: {
            SurfaceCard {
                HStack(spacing: Space.s3) {
                    IconTile(icon)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: name)
                            .font(Typography.cardTitle)
                            .lineLimit(large ? 2 : 1)
                        Text(line)
                            .font(Typography.secondary)
                            .foregroundStyle(Palette.onSurfaceVariant)
                        if large {
                            categoryLabel
                        }
                    }
                    if !large {
                        Spacer(minLength: Space.s2)
                        categoryLabel
                    }
                }
            }
        }
        .buttonStyle(.card)
    }

    private var categoryLabel: some View {
        Text(verbatim: category)
            .font(Typography.caption.weight(.medium))
            .foregroundStyle(Palette.onSurfaceVariant)
    }
}

private struct HistoryFigure: View {
    let icon: AppIcon
    let color: Color
    let value: String
    let label: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s2) {
                Image(icon: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                Text(verbatim: value)
                    .font(Typography.metricValue)
            }
            Text(verbatim: label)
                .font(Typography.secondary)
                .foregroundStyle(Palette.onSurfaceVariant)
            Text(verbatim: detail)
                .font(Typography.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
