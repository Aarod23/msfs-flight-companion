import SwiftUI

struct FlightDashboardView: View {
    let state: FlightState

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Live data grid
                liveDataGrid

                // ETA Card
                etaCard

                // Fuel card
                fuelCard

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
        .background(Color(hex: "#08091A"))
    }

    // MARK: - Live Data Grid
    var liveDataGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            DataTile(label: "ALT", value: state.alt > 0 ? "\(Int(state.alt).formattedWithSeparator)" : "——", unit: "ft")
            DataTile(label: "IAS", value: state.ias > 0 ? "\(Int(state.ias))" : "——", unit: "kts")
            DataTile(label: "GS",  value: state.gs  > 0 ? "\(Int(state.gs))"  : "——", unit: "kts")
            DataTile(label: "HDG", value: state.hdg > 0 ? "\(Int(state.hdg))" : "——", unit: "°T")
            DataTile(label: "V/S", value: state.vs != 0 ? "\(Int(state.vs) > 0 ? "+" : "")\(Int(state.vs))" : "——", unit: "fpm", valueColor: vsColor)
            DataTile(label: "FUEL", value: state.fuel > 0 ? "\(Int(state.fuel).formattedWithSeparator)" : "——", unit: "gal")
        }
        .padding(.horizontal, 16)
    }

    var vsColor: Color {
        if state.vs > 100 { return Color(hex: "#4A9EFF") }
        if state.vs < -100 { return Color(hex: "#F59E0B") }
        return .white
    }

    // MARK: - ETA Card
    var etaCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("ESTIMATED ARRIVAL")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(1.2)
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
                    Text("h")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Color(hex: "#7A8BB0"))
                    Text("\(m)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("m")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Color(hex: "#7A8BB0"))
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
        .padding(16)
        .background(Color(hex: "#0E1230").opacity(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#A855F7").opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    // MARK: - Fuel Card
    var fuelCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("FUEL")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(1.2)
                    .foregroundColor(Color(hex: "#7A8BB0"))
                Spacer()
                if let sb = state.simbrief {
                    Text("\(sb.fuel.units)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "#4A9EFF"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#4A9EFF").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }

            // Fuel bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(hex: "#EF4444"), location: 0),
                                .init(color: Color(hex: "#F59E0B"), location: 0.3),
                                .init(color: Color(hex: "#22D3A5"), location: 1)
                            ]),
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: fuelFillWidth(total: geo.size.width))
                        .animation(.spring(duration: 1), value: state.fuel)
                }
            }
            .frame(height: 10)

            HStack {
                Text("\(Int(state.fuel)) gal remaining")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                if let sb = state.simbrief {
                    Text("Rsv: \(sb.fuel.reserve) \(sb.fuel.units)")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#7A8BB0"))
                }
            }
        }
        .padding(16)
        .background(Color(hex: "#0E1230").opacity(0.85))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#4A9EFF").opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    func fuelFillWidth(total: CGFloat) -> CGFloat {
        guard let sb = state.simbrief, sb.fuel.block > 0 else { return 0 }
        // Approximate: fuel in gal vs block in lbs (rough)
        let pct = min(1.0, max(0, state.fuel / Double(sb.fuel.block) * 6.7))
        return total * CGFloat(pct)
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
                .font(.system(size: 9, weight: .bold))
                .kerning(1)
                .foregroundColor(Color(hex: "#3D4A6E"))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(valueColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(unit)
                .font(.system(size: 9))
                .foregroundColor(Color(hex: "#3D4A6E"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(hex: "#0E1230").opacity(0.85))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

extension Int {
    var formattedWithSeparator: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
