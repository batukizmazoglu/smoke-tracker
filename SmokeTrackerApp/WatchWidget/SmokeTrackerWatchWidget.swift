import WidgetKit
import SwiftUI
import SmokeTrackerCore
import SmokeTrackerData

struct CountEntry: TimelineEntry {
    let date: Date
    let count: Int
}

struct CountProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountEntry {
        CountEntry(date: Date(), count: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (CountEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountEntry>) -> Void) {
        let entry = currentEntry()
        // Gün dönümünde otomatik yenile (sayaç sıfırlansın).
        let nextMidnight = Calendar.current.nextDate(
            after: entry.date,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? entry.date.addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func currentEntry() -> CountEntry {
        let store = FileEventStore(url: SharedContainer.watchEventsURL())
        let count = StatsEngine(calendar: .current).count(on: Date(), events: store.allEvents())
        return CountEntry(date: Date(), count: count)
    }
}

struct SmokeTrackerWatchWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CountEntry

    var body: some View {
        content
            .widgetURL(URL(string: "smoketracker://log"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Label("\(entry.count) sigara", systemImage: "plus.circle")
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "plus")
                    .font(.caption2)
                Text("\(entry.count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
        case .accessoryCorner:
            Text("\(entry.count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .widgetLabel("sigara")
        default: // .accessoryRectangular
            HStack {
                Image(systemName: "plus.circle.fill")
                VStack(alignment: .leading) {
                    Text("Bugün")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(entry.count) sigara")
                        .font(.headline)
                }
            }
        }
    }
}

struct SmokeTrackerWatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SmokeTrackerWatchWidget", provider: CountProvider()) { entry in
            SmokeTrackerWatchWidgetView(entry: entry)
        }
        .configurationDisplayName("Sigara")
        .description("Bugünkü sayı; dokununca +1.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .accessoryCorner])
    }
}

@main
struct SmokeTrackerWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        SmokeTrackerWatchWidget()
    }
}
