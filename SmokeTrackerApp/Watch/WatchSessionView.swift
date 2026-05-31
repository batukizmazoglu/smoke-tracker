import SwiftUI
import SmokeTrackerCore

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

                if SessionAvailability.isBlocked(model.motionStatus) {
                    Text("Hareket izni kapalı. Seans için Watch Ayarları > Gizlilik ve Güvenlik > Hareket ve Fitness'ten aç. \"+1\" her zaman çalışır.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else if SessionAvailability.shouldPromptForMotion(model.motionStatus) {
                    Button {
                        model.requestMotionPermission()
                    } label: {
                        Label("Hareket iznini ver", systemImage: "hand.raised")
                            .frame(maxWidth: .infinity)
                    }
                }

                Button {
                    model.startSession()
                } label: {
                    Label("Seans başlat", systemImage: "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(SessionAvailability.isBlocked(model.motionStatus))

                Toggle("Eğitim verisi topla", isOn: $model.trainingDataConsent)
                    .font(.caption)
            }
        }
        .padding()
        .navigationTitle("Seans")
        .onAppear { model.refreshMotionStatus() }
    }
}
