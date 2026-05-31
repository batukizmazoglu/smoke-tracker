import SwiftUI

struct WatchTodayView: View {
    let model: WatchModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("\(model.todayCount)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("bugün")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    model.logOne()
                } label: {
                    Label("Sigara", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                NavigationLink {
                    WatchSessionView(model: model)
                } label: {
                    Label("Seans", systemImage: "record.circle")
                }
            }
            .padding()
        }
    }
}
