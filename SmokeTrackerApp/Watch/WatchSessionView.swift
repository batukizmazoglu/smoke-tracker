import SwiftUI

struct WatchSessionView: View {
    @Bindable var model: WatchModel

    var body: some View {
        VStack(spacing: 12) {
            if model.isRecordingSession {
                Text("Seans kaydı sürüyor")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                ProgressView()
                Button(role: .destructive) {
                    model.stopSession()
                } label: {
                    Label("Bitir (+1)", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
            } else {
                Text("Sensörlü seans")
                    .font(.headline)
                Text("Başlat; içerken bilek hareketini kaydedelim, bitince +1 işlenir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    model.startSession()
                } label: {
                    Label("Seans başlat", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Toggle("Eğitim verisi topla", isOn: $model.trainingDataConsent)
                    .font(.caption)
            }
        }
        .padding()
        .navigationTitle("Seans")
    }
}
