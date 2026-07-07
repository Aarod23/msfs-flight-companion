import SwiftUI

struct TimesView: View {
    let state: FlightState

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Main times
                VStack(spacing: 0) {
                    TimeRow(code: "STD", label: "Sched. Departure",  value: fmtISO(state.simbrief?.times.std), kind: .planned, extra: nil)
                    Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
                    TimeRow(code: "ATD", label: "Actual Departure",  value: fmtMS(state.atd),   kind: .actual,  extra: nil)
                    Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
                    TimeRow(code: "STA", label: "Sched. Arrival",   value: fmtISO(state.simbrief?.times.sta), kind: .planned, extra: nil)
                    Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 16)
                    TimeRow(code: "ETA", label: "Est. Arrival",      value: fmtDate(state.etaDate), kind: .eta,
                            extra: state.simbrief.flatMap { sb in
                                guard let sta = sb.times.sta, let eta = state.etaDate else { return nil }
                                let diff = eta.timeIntervalSince(ISO8601DateFormatter().date(from: sta) ?? eta)
                                return diff > 60 ? "+\(Int(diff/60))m late" : diff < -60 ? "\(Int(diff/60))m early" : "On time"
                            })
                }
                .background(Color(hex: "#0E1230").opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)

                // Big remaining card
                remainingCard

                // Stats row
                HStack(spacing: 10) {
                    StatCard(title: "Block Time", value: fmtSeconds(state.simbrief?.times.blockTime))
                    StatCard(title: "Enroute",    value: fmtSeconds(state.simbrief?.times.ete))
                    StatCard(title: "Elapsed",    value: fmtElapsed)
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .background(Color(hex: "#08091A"))
    }

    // MARK: - Remaining Card
    var remainingCard: some View {
        VStack(spacing: 6) {
            Text("TIME REMAINING")
                .font(.system(size: 10, weight: .semibold))
                .kerning(1.2)
                .foregroundColor(Color(hex: "#7A8BB0"))

            if let eta = state.etaDate {
                let rem = max(0, eta.timeIntervalSinceNow)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(rem / 3600))")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#A855F7"))
                    Text("h")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(Color(hex: "#7A8BB0"))
                        .padding(.trailing, 4)
                    Text("\(Int(rem.truncatingRemainder(dividingBy: 3600) / 60))")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#A855F7"))
                    Text("m")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(Color(hex: "#7A8BB0"))
                }
            } else {
                Text("——h ——m")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#3D4A6E"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(hex: "#0E1230").opacity(0.85))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#A855F7").opacity(0.2), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    // MARK: - Formatters
    var fmtElapsed: String {
        guard let atd = state.atdDate else { return "——" }
        let s = Date().timeIntervalSince(atd)
        return fmtSeconds(Int(s))
    }

    func fmtISO(_ iso: String?) -> String {
        guard let iso, let d = ISO8601DateFormatter().date(from: iso) else { return "——:——" }
        return fmtDate(d)
    }

    func fmtDate(_ d: Date?) -> String {
        guard let d else { return "——:——" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: d) + "Z"
    }

    func fmtMS(_ ms: Double?) -> String {
        guard let ms else { return "——:——" }
        return fmtDate(Date(timeIntervalSince1970: ms / 1000))
    }

    func fmtSeconds(_ s: Int?) -> String {
        guard let s, s > 0 else { return "——" }
        let h = s / 3600, m = (s % 3600) / 60
        return "\(h)h \(String(format: "%02d", m))m"
    }
}

// MARK: - Time Row
struct TimeRow: View {
    enum Kind { case planned, actual, eta }

    let code: String
    let label: String
    let value: String
    let kind: Kind
    let extra: String?

    var codeColor: Color {
        switch kind {
        case .planned: return Color(hex: "#4A9EFF")
        case .actual:  return Color(hex: "#22D3A5")
        case .eta:     return Color(hex: "#A855F7")
        }
    }
    var codeBG: Color { codeColor.opacity(0.12) }

    var body: some View {
        HStack(spacing: 14) {
            Text(code)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(codeColor)
                .frame(width: 36)
                .padding(.vertical, 4)
                .background(codeBG)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#7A8BB0"))
                if let extra {
                    Text(extra)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(extra.contains("+") ? Color(hex: "#EF4444") : Color(hex: "#22D3A5"))
                }
            }
            Spacer()
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .kerning(0.8)
                .foregroundColor(Color(hex: "#7A8BB0"))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(hex: "#0E1230").opacity(0.85))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
