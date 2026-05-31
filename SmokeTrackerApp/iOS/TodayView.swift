import SwiftUI

struct TodayView: View {
    let model: PhoneModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Bugün")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("\(model.todayCount)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                Text("Bu hafta: \(model.weekCount)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                NavigationLink {
                    HistoryView(events: model.history)
                } label: {
                    Label("Geçmiş", systemImage: "list.bullet")
                }
                .padding(.top, 8)
                NavigationLink {
                    TrainingDataView(model: model)
                } label: {
                    Label("Eğitim verisi", systemImage: "waveform.path.ecg")
                }
            }
            .padding()
            .navigationTitle("Sigara Takip")
        }
    }
}
