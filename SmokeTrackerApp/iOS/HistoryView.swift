import SwiftUI
import SmokeTrackerCore

struct HistoryView: View {
    let events: [SmokingEvent]

    /// Olayları güne göre gruplar; günler azalan (yeni → eski), gün içindeki
    /// olaylar da azalan sırada.
    private var sections: [(day: Date, events: [SmokingEvent])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: events) { calendar.startOfDay(for: $0.timestamp) }
        return groups
            .map { (day: $0.key, events: $0.value.sorted { $0.timestamp > $1.timestamp }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        Group {
            if events.isEmpty {
                ContentUnavailableView {
                    Label("Kayıt yok", systemImage: "list.bullet")
                } description: {
                    Text("Eklediğin kayıtlar gün gün burada listelenir.")
                }
            } else {
                List {
                    ForEach(sections, id: \.day) { section in
                        Section {
                            ForEach(section.events) { event in
                                HistoryRow(event: event)
                            }
                        } header: {
                            HStack {
                                Text(section.day, format: .dateTime.weekday().day().month())
                                Spacer()
                                Text("\(section.events.count)")
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Geçmiş")
    }
}

private struct HistoryRow: View {
    let event: SmokingEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.source.iconName)
                .foregroundStyle(.tint)
                .frame(width: 22)
            Text(event.timestamp, format: .dateTime.hour().minute())
                .monospacedDigit()
            Spacer()
            Text(event.source.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private extension EventSource {
    var label: String {
        switch self {
        case .tap:           return "Dokunma"
        case .session:       return "Seans"
        case .autoConfirmed: return "Otomatik"
        }
    }

    var iconName: String {
        switch self {
        case .tap:           return "hand.tap"
        case .session:       return "record.circle"
        case .autoConfirmed: return "sparkles"
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView(events: [
            SmokingEvent(id: UUID(), timestamp: .now.addingTimeInterval(-1_800), source: .tap),
            SmokingEvent(id: UUID(), timestamp: .now.addingTimeInterval(-7_200), source: .session),
            SmokingEvent(id: UUID(), timestamp: .now.addingTimeInterval(-12_600), source: .autoConfirmed),
            SmokingEvent(id: UUID(), timestamp: .now.addingTimeInterval(-90_000), source: .tap),
            SmokingEvent(id: UUID(), timestamp: .now.addingTimeInterval(-95_400), source: .session),
        ])
    }
}
