import SwiftUI
import WidgetKit

struct SweepAlertWidgetEntry: TimelineEntry {
    let date: Date
    let carName: String
    let streetName: String
    let streetSide: String
    let timeWindow: String
    let nextCleaningLabel: String
    let statusLabel: String
}

struct SweepAlertWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SweepAlertWidgetEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (SweepAlertWidgetEntry) -> Void) {
        completion(.sample)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SweepAlertWidgetEntry>) -> Void) {
        let entry = SweepAlertWidgetEntry.sample
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3_600)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

struct SweepAlertWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SweepAlertWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumLayout
        default:
            smallLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            Spacer(minLength: 4)

            Text(entry.statusLabel)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.streetName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)

                Text("\(entry.streetSide) side - \(entry.timeWindow)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .widgetCard()
    }

    private var mediumLayout: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 9) {
                header

                Text(entry.statusLabel)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text("\(entry.streetName) - \(entry.streetSide) side - \(entry.timeWindow)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(sweepGreen)
                    .clipShape(Circle())

                Text(entry.nextCleaningLabel)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(sweepGreen)
                    .multilineTextAlignment(.trailing)

                Text(entry.carName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
        }
        .widgetCard()
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "car.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(sweepBlue)
                .clipShape(Circle())

            Text("SweepAlert")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
        }
    }
}

@main
struct SweepAlertWidget: Widget {
    let kind = "SweepAlertWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SweepAlertWidgetProvider()) { entry in
            SweepAlertWidgetView(entry: entry)
                .containerBackground(Color(.systemBackground), for: .widget)
                .widgetURL(URL(string: "ai.revyl.sweepalert.swift://widget"))
        }
        .configurationDisplayName("SweepAlert")
        .description("See the next street cleaning window for your shared car.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private extension SweepAlertWidgetEntry {
    static var sample: SweepAlertWidgetEntry {
        SweepAlertWidgetEntry(
            date: Date(),
            carName: "Roommates' Honda",
            streetName: "Bush St",
            streetSide: "North",
            timeWindow: "9am-11am",
            nextCleaningLabel: "Tue, May 19",
            statusLabel: "Street cleaning in 9 days"
        )
    }
}

private extension View {
    func widgetCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private let sweepBlue = Color(red: 0.05, green: 0.39, blue: 0.90)
private let sweepGreen = Color(red: 0.20, green: 0.78, blue: 0.42)

#Preview(as: .systemMedium) {
    SweepAlertWidget()
} timeline: {
    SweepAlertWidgetEntry.sample
}
