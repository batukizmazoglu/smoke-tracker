import SwiftUI
import SmokeTrackerCore

struct TrainingDataView: View {
    @Bindable var model: PhoneModel

    var body: some View {
        List {
            Section {
                Toggle("Eğitim verisi toplamaya izin ver", isOn: $model.trainingDataConsent)
                Text("Sensörlü seanslardaki ham hareket verisi, ileride sigara içme hareketini otomatik tanımak için kullanılacak. Yalnızca açık izninle saklanır; istediğin an silebilirsin.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Kayıtlı seanslar (\(model.trainingSessions.count))") {
                if model.trainingSessions.isEmpty {
                    Text("Henüz kayıt yok")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.trainingSessions) { session in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.recordedAt, format: .dateTime.day().month().hour().minute())
                            Text("\(session.samples.count) örnek")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { model.trainingSessions[$0] }
                            .forEach(model.deleteTrainingSession)
                    }
                    Button(role: .destructive) {
                        model.deleteAllTrainingData()
                    } label: {
                        Text("Tüm eğitim verisini sil")
                    }
                }
            }
        }
        .navigationTitle("Eğitim verisi")
    }
}
