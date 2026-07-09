import SwiftUI

// ─────────────────────────────────────────────────────────────
// MARK: - Flight Sheet Content
// The scrollable content inside the bottom sheet.
// Inspired by FlightTrackApp's premium dark aviation aesthetic.
// ─────────────────────────────────────────────────────────────

struct FlightSheetContent: View {
    let vm: FlightViewModel
    let isExpanded: Bool
    @Binding var laActive: Bool
    let onStartLA:  () -> Void
    let onEndLA:    () -> Void
    let onSettings: () -> Void
    let onTimes:    () -> Void

    var state: FlightState { vm.state }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // ── Route Header ─────────────────────────────
                routeHeader
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)

                divider

                // ── Airport Rows ──────────────────────────────
                if state.simbrief != nil {
                    airportRow(
                        direction: "departure",
                        icao:  state.simbrief?.origin.icao      ?? "——",
                        name:  state.simbrief?.origin.name      ?? "——",
                        timeStr: fmtAtd(state.atd),
                        label: "ATD",
                        statusLabel: atdStatus,
                        statusColor: atdStatusColor
                    )

                    divider.padding(.leading, 20)

                    airportRow(
                        direction: "arrival",
                        icao:  state.simbrief?.destination.icao ?? "——",
                        name:  state.simbrief?.destination.name ?? "——",
                        timeStr: fmtDate(state.etaDate),
                        label: "ETA",
                        statusLabel: etaStatus,
                        statusColor: etaStatusColor
                    )
                } else {
                    noFlightCard
                }

                divider

                // ── Live Telemetry Row ────────────────────────
                telemetryRow
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                divider

                // ── Phase Timeline ────────────────────────────
                phaseTimeline
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                if isExpanded {
                    divider

                    // ── Fuel Bar ─────────────────────────────
                    fuelSection
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)

                    // ── Wind + TOD ───────────────────────────
                    if state.windSpeed > 0 || todMinutes != nil {
                        divider
                        windTODRow
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                    }
                }

                divider

                // ── Action Bar ───────────────────────────────
                actionBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .padding(.bottom, 24)
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    // MARK: - Route Header
    // ══════════════════════════════════════════════════════════
    var routeHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            // Origin
            VStack(alignment: .leading, spacing: 2) {
                Text(state.simbrief?.origin.icao ?? "——")
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(state.simbrief?.origin.name.components(separatedBy: " ").prefix(2).joined(separator: " ") ?? "——")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#666"))
                    .lineLimit(1)
            }
            Spacer()
            // Progress line + plane
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Full track
                    Rectangle()
                        .fill(Color(hex: "#222"))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                    // Flown
                    Rectangle()
                        .fill(Color(hex: "#00C853"))
                        .frame(width: geo.size.width * CGFloat(state.progressPercent / 100), height: 1.5)
                    // Plane icon at progress point
                    Image(systemName: "airplane")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .offset(x: geo.size.width * CGFloat(state.progressPercent / 100) - 10)
                        .animation(.spring(duration: 0.6), value: state.progressPercent)
                }
            }
            .frame(height: 20)
            .padding(.horizontal, 12)
            Spacer()
            // Destination
            VStack(alignment: .trailing, spacing: 2) {
                Text(state.simbrief?.destination.icao ?? "——")
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(state.simbrief?.destination.name.components(separatedBy: " ").prefix(2).joined(separator: " ") ?? "——")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#666"))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 16)
    }

    // ══════════════════════════════════════════════════════════
    // MARK: - Airport Row
    // ══════════════════════════════════════════════════════════
    func airportRow(direction: String, icao: String, name: String,
                    timeStr: String, label: String,
                    statusLabel: String, statusColor: Color) -> some View {
        HStack(spacing: 16) {
            // Direction arrow
            Image(systemName: direction == "departure" ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(direction == "departure" ? Color(hex: "#00C853") : Color(hex: "#42A5F5"))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(icao)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#555"))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(timeStr)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                HStack(spacing: 4) {
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(hex: "#555"))
                    Text(statusLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(statusColor)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }

    // ══════════════════════════════════════════════════════════
    // MARK: - Telemetry Row
    // ══════════════════════════════════════════════════════════
    var telemetryRow: some View {
        HStack(spacing: 0) {
            telemCell(label: "ALT", value: state.alt > 0 ? "FL\(Int(state.alt / 100))" : "——")
            telemDivider
            telemCell(label: "IAS", value: state.ias > 0 ? "\(Int(state.ias))" : "——", unit: "kts")
            telemDivider
            telemCell(label: "GS",  value: state.gs  > 0 ? "\(Int(state.gs))"  : "——", unit: "kts")
            telemDivider
            vsCell
        }
    }

    func telemCell(label: String, value: String, unit: String = "") -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold)).kerning(1)
                .foregroundColor(Color(hex: "#444"))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: value)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#444"))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    var vsCell: some View {
        VStack(spacing: 4) {
            Text("V/S")
                .font(.system(size: 9, weight: .semibold)).kerning(1)
                .foregroundColor(Color(hex: "#444"))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(state.vs != 0 ? (state.vs > 0 ? "+" : "") + "\(Int(state.vs))" : "0")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(vsColor)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: Int(state.vs))
                Image(systemName: state.vs > 100 ? "arrow.up" : state.vs < -100 ? "arrow.down" : "minus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(vsColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    var vsColor: Color {
        state.vs > 100 ? Color(hex: "#42A5F5") : state.vs < -100 ? Color(hex: "#FFA726") : Color(hex: "#555")
    }

    func telemDivider() -> some View {
        Rectangle()
            .fill(Color(hex: "#1E1E1E"))
            .frame(width: 1, height: 32)
    }

    // ══════════════════════════════════════════════════════════
    // MARK: - Phase Timeline
    // ══════════════════════════════════════════════════════════
    let allPhases = ["PREFLIGHT","TAXI","TAKEOFF","CLIMB","CRUISE","DESCENT","APPROACH","LANDED"]

    var currentPhaseIdx: Int { allPhases.firstIndex(of: state.phase) ?? 0 }

    var phaseTimeline: some View {
        HStack(spacing: 0) {
            ForEach(Array(allPhases.enumerated()), id: \.offset) { i, ph in
                let done    = i < currentPhaseIdx
                let current = i == currentPhaseIdx
                HStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(done || current ? phaseColor(ph) : Color(hex: "#1C1C1C"))
                            .frame(width: current ? 10 : 6, height: current ? 10 : 6)
                        if current {
                            Circle()
                                .stroke(phaseColor(ph).opacity(0.35), lineWidth: 2)
                                .frame(width: 17, height: 17)
                        }
                    }
                    .animation(.spring(duration: 0.5), value: currentPhaseIdx)

                    if i < allPhases.count - 1 {
                        Rectangle()
                            .fill(done
                                  ? LinearGradient(colors: [phaseColor(ph), phaseColor(allPhases[i+1])],
                                                   startPoint: .leading, endPoint: .trailing)
                                  : LinearGradient(colors: [Color(hex: "#1C1C1C"), Color(hex: "#1C1C1C")],
                                                   startPoint: .leading, endPoint: .trailing))
                            .frame(height: 1.5)
                            .animation(.easeInOut(duration: 0.6), value: currentPhaseIdx)
                    }
                }
                .frame(maxWidth: i < allPhases.count - 1 ? .infinity : nil)
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    // MARK: - Fuel Section
    // ══════════════════════════════════════════════════════════
    var fuelSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("FUEL")
                    .font(.system(size: 9, weight: .semibold)).kerning(1)
                    .foregroundColor(Color(hex: "#444"))
                Spacer()
                Text("\(Int(state.fuel).fmtThousands) gal")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#1A1A1A")).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(
                            colors: [Color(hex: "#EF5350"), Color(hex: "#FFC107"), Color(hex: "#00C853")],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: fuelBarWidth(geo.size.width), height: 6)
                        .animation(.spring(duration: 1.2), value: state.fuel)
                }
            }.frame(height: 6)
            HStack {
                if let sb = state.simbrief {
                    Text("Reserve: \(sb.fuel.reserve) gal")
                        .font(.system(size: 10)).foregroundColor(Color(hex: "#444"))
                    Spacer()
                    Text("\(Int((state.fuel / Double(max(1, sb.fuel.block)) * 6.7) * 100))%")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: "#666"))
                }
            }
        }
    }

    func fuelBarWidth(_ total: CGFloat) -> CGFloat {
        guard let sb = state.simbrief, sb.fuel.block > 0 else { return 0 }
        return total * CGFloat(min(1.0, state.fuel / Double(sb.fuel.block) * 6.7))
    }

    // ══════════════════════════════════════════════════════════
    // MARK: - Wind + TOD Row
    // ══════════════════════════════════════════════════════════
    var todMinutes: Int? {
        guard let sb = state.simbrief, state.phase == "CRUISE",
              state.alt > 5000, state.gs > 100 else { return nil }
        let nmDest = greatCircleDistanceNm(lat1: state.lat, lon1: state.lon,
                                           lat2: sb.destination.lat, lon2: sb.destination.lon)
        let nmForDescent = max(0, state.alt - 1500) / 1000.0 * 3.0
        let nmToTOD = nmDest - nmForDescent
        guard nmToTOD > 0 else { return nil }
        return Int(nmToTOD / state.gs * 60)
    }

    var windTODRow: some View {
        HStack(spacing: 0) {
            if state.windSpeed > 0 {
                VStack(spacing: 4) {
                    Text(state.headwindKt >= 0 ? "HEADWIND" : "TAILWIND")
                        .font(.system(size: 8, weight: .semibold)).kerning(0.8)
                        .foregroundColor(Color(hex: "#444"))
                    Text("\(abs(Int(state.headwindKt))) kt")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(state.headwindKt >= 0 ? Color(hex: "#EF5350") : Color(hex: "#00C853"))
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)

                telemDivider()
            }

            if state.windSpeed > 0 {
                VStack(spacing: 4) {
                    Text("WIND").font(.system(size: 8, weight: .semibold)).kerning(0.8)
                        .foregroundColor(Color(hex: "#444"))
                    Text("\(Int(state.windDir))°/\(Int(state.windSpeed))kt")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
            }

            if let tod = todMinutes {
                if state.windSpeed > 0 { telemDivider() }
                VStack(spacing: 4) {
                    Text("TOD IN").font(.system(size: 8, weight: .semibold)).kerning(0.8)
                        .foregroundColor(Color(hex: "#444"))
                    Text("\(tod) min")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#FFC107"))
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    // MARK: - Action Bar
    // ══════════════════════════════════════════════════════════
    var actionBar: some View {
        HStack(spacing: 12) {
            // Dynamic Island button (primary)
            Button {
                laActive ? onEndLA() : onStartLA()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: laActive
                          ? "iphone.gen3.radiowaves.left.and.right"
                          : "iphone.gen3.radiowaves.left.and.right")
                        .font(.system(size: 16, weight: .semibold))
                    Text(laActive ? "Island Active" : "Dynamic Island")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(laActive ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(laActive ? Color(hex: "#00C853") : Color(hex: "#1A1A1A"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(laActive ? .clear : Color(hex: "#2A2A2A"), lineWidth: 1)
                )
            }
            .animation(.spring(duration: 0.3), value: laActive)

            // Times button
            Button(action: onTimes) {
                Image(systemName: "clock")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "#888"))
                    .frame(width: 48, height: 48)
                    .background(Color(hex: "#1A1A1A"))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Settings button
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "#888"))
                    .frame(width: 48, height: 48)
                    .background(Color(hex: "#1A1A1A"))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    // MARK: - No Flight Placeholder
    // ══════════════════════════════════════════════════════════
    var noFlightCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 36))
                .foregroundColor(Color(hex: "#2A2A2A"))
            Text("No SimBrief plan loaded")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#444"))
            Text("Load a plan in SimBrief and launch MSFS")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#333"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
    }

    // MARK: - Divider
    var divider: some View {
        Rectangle()
            .fill(Color(hex: "#1A1A1A"))
            .frame(height: 1)
    }

    // MARK: - Formatters
    func fmtDate(_ d: Date?) -> String {
        guard let d else { return "——:——" }
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: d) + "Z"
    }

    func fmtAtd(_ ms: Double?) -> String {
        guard let ms else { return "——:——" }
        return fmtDate(Date(timeIntervalSince1970: ms / 1000))
    }

    // MARK: - Status helpers
    var atdStatus: String {
        guard state.atd != nil else { return "——" }
        guard let sb = state.simbrief, let std = sb.times.std,
              let atd = state.atd, let stdDate = ISO8601DateFormatter().date(from: std)
        else { return "DEPARTED" }
        let diff = atd / 1000 - stdDate.timeIntervalSince1970
        if diff > 60  { return "+\(Int(diff/60))m" }
        if diff < -60 { return "-\(abs(Int(diff/60)))m" }
        return "ON TIME"
    }

    var atdStatusColor: Color {
        let s = atdStatus
        if s == "ON TIME" || s == "DEPARTED" { return Color(hex: "#00C853") }
        if s.hasPrefix("+") { return Color(hex: "#EF5350") }
        return Color(hex: "#42A5F5")
    }

    var etaStatus: String {
        guard let eta = state.etaDate else { return "——" }
        guard let sb = state.simbrief, let sta = sb.times.sta,
              let staDate = ISO8601DateFormatter().date(from: sta)
        else { return "ESTIMATED" }
        let diff = eta.timeIntervalSince(staDate)
        if diff > 60  { return "+\(Int(diff/60))m" }
        if diff < -60 { return "-\(abs(Int(diff/60)))m" }
        return "ON TIME"
    }

    var etaStatusColor: Color {
        let s = etaStatus
        if s == "ON TIME" || s == "ESTIMATED" { return Color(hex: "#00C853") }
        if s.hasPrefix("+") { return Color(hex: "#EF5350") }
        return Color(hex: "#42A5F5")
    }
}

// MARK: - Int formatting
extension Int {
    var fmtThousands: String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
