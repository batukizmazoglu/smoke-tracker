import SwiftUI
import SmokeTrackerCore

struct TrainingDataView: View {
    @Bindable var model: PhoneModel

    var body: some View {
        List {
            Section {
                Toggle("Eğitim verisi toplamaya izin ver", isOn: $model.trainingDataConsent)
                Text("Sensörlü seanslardaki ham hareket verisi, ileride sigara içme hareketini " +
                     "otomatik tanımak için kullanılacak. Yalnızca açık izninle saklanır; istediğin an silebilirsin.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Toplanan veri") {
                let positive = model.trainingSessions.filter { $0.label == TrainingLabel.smoking }.count
                let negative = model.trainingSessions.filter { $0.label == TrainingLabel.notSmoking }.count
                LabeledContent("Sigara (pozitif)", value: "\(positive)")
                LabeledContent("Sigara değil (negatif)", value: "\(negative)")
                Text("Dengeli pozitif + negatif örnek, ileride otomatik tanıma modelini eğitmek için gerekli.")
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
