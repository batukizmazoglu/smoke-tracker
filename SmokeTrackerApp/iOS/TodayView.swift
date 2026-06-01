import SwiftUI
import Charts
import SmokeTrackerCore

struct TodayView: View {
    let model: PhoneModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hero
                    streakBanner
                    if model.history.isEmpty {
                        emptyHint
                    } else {
                        statsRow
                        weeklyCard
                    }
                    navCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sigara Takip")
        }
    }

    // MARK: - Kahraman sayaç

    private var hero: some View {
        VStack(spacing: 2) {
            Text("BUGÜN")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(.secondary)
            Text("\(model.todayCount)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("sigara")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bugün \(model.todayCount) sigara")
    }

    /// Bugün hiç içilmediyse, son içimden bu yana geçen gün sayısını kutlar.
    @ViewBuilder private var streakBanner: some View {
        if model.todayCount == 0, let days = model.daysSinceLast, days >= 1 {
            Label(days == 1 ? "1 gündür sigara yok" : "\(days) gündür sigara yok",
                  systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - İçgörü kartları

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "Bu hafta", value: "\(model.weekCount)", systemImage: "calendar")
            StatCard(title: "Günlük ort.", value: model.dailyAverage.formatted(.number.precision(.fractionLength(1))), systemImage: "chart.bar")
            StatCard(title: "Toplam", value: "\(model.history.count)", systemImage: "sum")
        }
    }

    // MARK: - Haftalık grafik

    private var weeklyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Son 7 gün").font(.headline)
                Spacer()
                trendBadge
            }
            Chart(model.chartDays, id: \.day) { day in
                BarMark(
                    x: .value("Gün", day.day, unit: .day),
                    y: .value("Adet", day.count)
                )
                .cornerRadius(5)
                .foregroundStyle(Calendar.current.isDateInToday(day.day)
                                 ? Color.accentColor
                                 : Color.accentColor.opacity(0.3))
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
            }
            .chartXAxis {
                AxisMarks(values: model.chartDays.map(\.day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 150)
            Text(trendDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var trendDelta: Int { model.last7Count - model.previous7Count }

    @ViewBuilder private var trendBadge: some View {
        if model.last7Count == 0 && model.previous7Count == 0 {
            EmptyView()
        } else if trendDelta < 0 {
            Label("\(abs(trendDelta))", systemImage: "arrow.down.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
        } else if trendDelta > 0 {
            Label("\(trendDelta)", systemImage: "arrow.up.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
        } else {
            Label("0", systemImage: "equal")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var trendDescription: String {
        if model.last7Count == 0 && model.previous7Count == 0 {
            return "Son iki haftada kayıt yok."
        }
        switch trendDelta {
        case ..<0:  return "Önceki 7 güne göre \(abs(trendDelta)) daha az — güzel gidiyor."
        case 0:     return "Önceki 7 günle aynı seviyede."
        default:    return "Önceki 7 güne göre \(trendDelta) daha fazla."
        }
    }

    // MARK: - Boş durum

    private var emptyHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "lungs")
                .font(.system(size: 36))
                .foregroundStyle(.tint)
            Text("Henüz kayıt yok")
                .font(.headline)
            Text("Apple Watch'undaki complication'a ya da widget'a dokunarak ilk kaydını ekle. İstatistikler burada belirir.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Navigasyon

    private var navCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                HistoryView(events: model.history)
            } label: {
                NavRow(title: "Geçmiş", systemImage: "list.bullet")
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 54)
            NavigationLink {
                TrainingDataView(model: model)
            } label: {
                NavRow(title: "Eğitim verisi", systemImage: "waveform.path.ecg")
            }
            .buttonStyle(.plain)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Yeniden kullanılabilir bileşenler

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct NavRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.body)
                .frame(width: 24)
                .foregroundStyle(.tint)
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
