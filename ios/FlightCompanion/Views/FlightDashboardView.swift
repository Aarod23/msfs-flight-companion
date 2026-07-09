import SwiftUI
import UIKit

// ─────────────────────────────────────────────────────────────
// MARK: - Dashboard View
// ─────────────────────────────────────────────────────────────
struct FlightDashboardView: View {
    let state: FlightState
    @State private var todPulse = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Live data grid (6 tiles)
                liveDataGrid

                // VS Gauge
                VSGaugeCard(vs: state.vs)

                // ETA Card
                etaCard

                // TOD Card (only in cruise)
                if state.phase == "CRUISE", let tod = todInfo {
                    todCard(tod)
                }

                // Fuel card
                fuelCard

                // Wind card (if we have data)
                if state.windSpeed > 0 {
                    windCard
                }

                // Start Live Activity button
                Button {
                    LiveActivityManager.shared.start(state: state)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                            .font(.system(size: 18))
                        Text("Start Dynamic Island")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "#4A9EFF"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#4A9EFF").opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#4A9EFF").opacity(0.3), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .background(Color.clear)
    }

    // MARK: - Live Data Grid
    var liveDataGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            DataTile(label: "ALT",  value: state.alt > 0  ? "\(Int(state.alt).fmtSep)"  : "——", unit: "ft")
            DataTile(label: "IAS",  value: state.ias > 0  ? "\(Int(state.ias))"          : "——", unit: "kts")
            DataTile(label: "GS",   value: state.gs  > 0  ? "\(Int(state.gs))"           : "——", unit: "kts")
            DataTile(label: "HDG",  value: state.hdg > 0  ? "\(Int(state.hdg))"          : "——", unit: "°T")
            DataTile(label: "NM",   value: nmRemaining    != nil ? "\(Int(nmRemaining!))" : "——", unit: "rem")
            DataTile(label: "FUEL", value: state.fuel > 0 ? "\(Int(state.fuel).fmtSep)"  : "——", unit: "gal")
        }
        .padding(.horizontal, 16)
    }

    var nmRemaining: Double? {
        guard let sb = state.simbrief, state.lat != 0 else { return nil }
        return greatCircleDistanceNm(lat1: state.lat, lon1: state.lon,
                                     lat2: sb.destination.lat, lon2: sb.destination.lon)
    }

    // MARK: - ETA Card
    var etaCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("ESTIMATED ARRIVAL")
                    .font(.system(size: 10, weight: .semibold)).kerning(1.2)
                    .foregroundColor(Color(hex: "#7A8BB0"))
                Spacer()
            }

            if let eta = state.etaDate {
                let remaining = eta.timeIntervalSinceNow
                let h = Int(remaining / 3600)
                let m = Int(remaining.truncatingRemainder(dividingBy: 3600) / 60)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(h)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.5), value: h)
                    Text("h").font(.system(size: 24, weight: .medium)).foregroundColor(Color(hex: "#7A8BB0"))
                    Text("\(m)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.5), value: m)
                    Text("m").font(.system(size: 24, weight: .medium)).foregroundColor(Color(hex: "#7A8BB0"))
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("ETA")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "#A855F7"))
                        Text(eta, format: .dateTime.hour().minute().timeZone())
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
            } else {
                Text("No active flight")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#3D4A6E"))
            }
        }
        .glassCard(borderColor: Color(hex: "#A855F7").opacity(0.3))
        .padding(.horizontal, 16)
    }

    // MARK: - TOD Card
    var todInfo: (minutes: Int, nmAway: Double)? {
        guard let sb = state.simbrief, state.alt > 5000, state.gs > 100 else { return nil }
        let nmToDest = greatCircleDistanceNm(lat1: state.lat, lon1: state.lon,
                                              lat2: sb.destination.lat, lon2: sb.destination.lon)
        // 3° path: descend 1000ft per 3nm, from cruiseAlt to 1500ft
        let altToLose = max(0, state.alt - 1500)
        let nmForDescent = altToLose / 1000.0 * 3.0
        let nmToTOD = nmToDest - nmForDescent
        guard nmToTOD > 0 else { return nil }
        let minutesToTOD = Int(nmToTOD / state.gs * 60)
        return (minutesToTOD, nmToTOD)
    }

    @ViewBuilder
    func todCard(_ tod: (minutes: Int, nmAway: Double)) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.down.right.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(Color(hex: "#F59E0B"))
                .scaleEffect(todPulse ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: todPulse)
                .onAppear { todPulse = true }

            VStack(alignment: .leading, spacing: 4) {
                Text("TOP OF DESCENT")
                    .font(.system(size: 9, weight: .bold)).kerning(1.2)
                    .foregroundColor(Color(hex: "#7A8BB0"))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("in \(tod.minutes)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#F59E0B"))
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.5), value: tod.minutes)
                    Text("min")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#7A8BB0"))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(tod.nmAway)) NM")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("to TOD")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#7A8BB0"))
            }
        }
        .glassCard(borderColor: Color(hex: "#F59E0B").opacity(0.3))
        .padding(.horizontal, 16)
    }

    // MARK: - Fuel Card
    var fuelCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("FUEL")
                    .font(.system(size: 10, weight: .semibold)).kerning(1.2)
                    .foregroundColor(Color(hex: "#7A8BB0"))
                Spacer()
                if let sb = state.simbrief {
                    Text(sb.fuel.units)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "#4A9EFF"))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(hex: "#4A9EFF").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(gradient: Gradient(stops: [
                            .init(color: Color(hex: "#EF4444"), location: 0),
                            .init(color: Color(hex: "#F59E0B"), location: 0.3),
                            .init(color: Color(hex: "#22D3A5"), location: 1)
                        ]), startPoint: .leading, endPoint: .trailing))
                        .frame(width: fuelFillWidth(total: geo.size.width))
                        .animation(.spring(duration: 1), value: state.fuel)
                }
            }
            .frame(height: 10)
            HStack {
                Text("\(Int(state.fuel).fmtSep) gal remaining")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.5), value: Int(state.fuel))
                Spacer()
                if let sb = state.simbrief {
                    Text("Rsv: \(sb.fuel.reserve) \(sb.fuel.units)")
                        .font(.system(size: 11)).foregroundColor(Color(hex: "#7A8BB0"))
                }
            }
        }
        .glassCard(borderColor: Color(hex: "#4A9EFF").opacity(0.15))
        .padding(.horizontal, 16)
    }

    // MARK: - Wind Card
    var windCard: some View {
        HStack(spacing: 20) {
            windComponent(
                label: state.headwindKt >= 0 ? "HEADWIND" : "TAILWIND",
                value: abs(Int(state.headwindKt)),
                color: state.headwindKt >= 0 ? Color(hex: "#EF4444") : Color(hex: "#22D3A5"),
                icon: state.headwindKt >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
            )
            Divider().background(Color.white.opacity(0.08)).frame(height: 40)
            windComponent(
                label: "CROSSWIND",
                value: abs(Int(state.crosswindKt)),
                color: Color(hex: "#F59E0B"),
                icon: "arrow.left.arrow.right.circle.fill"
            )
            Divider().background(Color.white.opacity(0.08)).frame(height: 40)
            windComponent(
                label: "WIND",
                value: Int(state.windSpeed),
                color: Color(hex: "#A855F7"),
                icon: "wind"
            )
        }
        .glassCard(borderColor: Color(hex: "#A855F7").opacity(0.2))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    func windComponent(label: String, value: Int, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 20)).foregroundColor(color)
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 8, weight: .semibold)).kerning(0.8)
                .foregroundColor(Color(hex: "#7A8BB0"))
        }
        .frame(maxWidth: .infinity)
    }

    func fuelFillWidth(total: CGFloat) -> CGFloat {
        guard let sb = state.simbrief, sb.fuel.block > 0 else { return 0 }
        let pct = min(1.0, max(0, state.fuel / Double(sb.fuel.block) * 6.7))
        return total * CGFloat(pct)
    }
}

// MARK: - VS Gauge Card
struct VSGaugeCard: View {
    let vs: Double
    private var clampedVs: Double { min(max(vs, -3000), 3000) }
    private var fraction: Double { clampedVs / 3000.0 }   // -1 to +1
    private var arcAngle: Double { fraction * 120 }         // -120° to +120°
    private var gaugeColor: Color {
        if vs > 100  { return Color(hex: "#4A9EFF") }
        if vs < -100 { return Color(hex: "#F59E0B") }
        return Color(hex: "#7A8BB0")
    }

    var body: some View {
        HStack(spacing: 20) {
            // Arc gauge
            ZStack {
                // Track
                Circle()
                    .trim(from: 0.17, to: 0.83)
                    .rotation(.degrees(90))
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)

                // Fill arc
                Circle()
                    .trim(from: 0.5, to: max(0.17, min(0.83, 0.5 + fraction * 0.33)))
                    .rotation(.degrees(90))
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .animation(.spring(duration: 0.6), value: vs)

                VStack(spacing: 0) {
                    Text(vs != 0 ? (vs > 0 ? "+" : "") + "\(Int(vs))" : "0")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(gaugeColor)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.4), value: Int(vs))
                    Text("fpm")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#7A8BB0"))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("VERTICAL SPEED")
                    .font(.system(size: 9, weight: .bold)).kerning(1.2)
                    .foregroundColor(Color(hex: "#7A8BB0"))

                HStack(spacing: 6) {
                    Image(systemName: vs > 100 ? "arrow.up.circle.fill" : vs < -100 ? "arrow.down.circle.fill" : "minus.circle.fill")
                        .foregroundColor(gaugeColor)
                    Text(vs > 100 ? "Climbing" : vs < -100 ? "Descending" : "Level flight")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }

                // Mini tick marks
                HStack(spacing: 4) {
                    ForEach([-3000, -2000, -1000, 0, 1000, 2000, 3000], id: \.self) { tick in
                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(abs(Int(vs)) >= abs(tick) && (vs > 0 ? tick >= 0 : tick <= 0) && tick != 0
                                      ? gaugeColor : Color.white.opacity(0.12))
                                .frame(width: 3, height: tick == 0 ? 12 : 8)
                                .clipShape(Capsule())
                            if tick == 0 || abs(tick) == 3000 {
                                Text(tick == 0 ? "0" : (tick > 0 ? "3k" : "-3k"))
                                    .font(.system(size: 7))
                                    .foregroundColor(Color(hex: "#7A8BB0"))
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .glassCard(borderColor: gaugeColor.opacity(0.2))
        .padding(.horizontal, 16)
    }
}

// MARK: - Data Tile
struct DataTile: View {
    let label: String
    let value: String
    let unit: String
    var valueColor: Color = .white

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold)).kerning(1)
                .foregroundColor(Color(hex: "#3D4A6E"))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(valueColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.35), value: value)
            Text(unit)
                .font(.system(size: 9))
                .foregroundColor(Color(hex: "#3D4A6E"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Glass Card Modifier
extension View {
    func glassCard(borderColor: Color = Color.white.opacity(0.08)) -> some View {
        self.padding(16)
            .background(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

extension Int {
    var fmtSep: String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
