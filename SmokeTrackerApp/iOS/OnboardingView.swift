import SwiftUI

/// İlk açılış akışı: ne yaptığı, gizlilik ve eğitim-verisi onayı. Son sayfada
/// "Başla" → model.completeOnboarding().
struct OnboardingView: View {
    @Bindable var model: PhoneModel
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            welcome.tag(0)
            howItWorks.tag(1)
            privacy.tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "lungs.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Sigara Takip")
                .font(.largeTitle.bold())
            Text("Gün içinde kaç sigara/IQOS içtiğini sade biçimde takip et. Hedef yok, yargı yok — sadece farkındalık.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            nextHint
        }
        .padding(32)
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Nasıl çalışır")
                .font(.title.bold())
            Label("Saat kadranındaki complication'a dokun → anında +1.", systemImage: "plus.circle.fill")
            Label("İstersen \"Seans\" başlat; bilek hareketi kaydedilir, bitince +1 işlenir.", systemImage: "record.circle")
            Label("Tüm veriler cihazında kalır (local-first). Satış yok.", systemImage: "lock.fill")
            Spacer()
            nextHint
        }
        .padding(32)
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Gizlilik ve onay")
                .font(.title.bold())
            Text("Sensörlü seanslardaki ham hareket verisi, ileride sigara içme hareketini otomatik tanımak için kullanılabilir. Bu tamamen opsiyoneldir ve yalnızca açık iznine bağlıdır; istediğin an silebilirsin.")
                .foregroundStyle(.secondary)
            Toggle("Eğitim verisi toplamaya izin ver", isOn: $model.trainingDataConsent)
            Spacer()
            Button {
                model.completeOnboarding()
            } label: {
                Text("Başla")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }

    private var nextHint: some View {
        Text("Devam etmek için kaydır")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
