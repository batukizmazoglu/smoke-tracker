import SwiftUI
import SmokeTrackerCore

struct HistoryView: View {
    let events: [SmokingEvent]

    var body: some View {
        List(events) { event in
            HStack {
                Text(event.timestamp, format: .dateTime.day().month().year())
                Spacer()
                Text(event.timestamp, format: .dateTime.hour().minute())
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Geçmiş")
    }
}
