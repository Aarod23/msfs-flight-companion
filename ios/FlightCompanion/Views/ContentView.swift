import SwiftUI

struct ContentView: View {
    @StateObject private var vm = FlightViewModel()
    @AppStorage("relayURL") var relayURL = "https://msfs-relay.onrender.com"
    @AppStorage("relayKey") var relayKey = "flight-companion-key"
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            // ── Phase-reactive background ───────────────────────
            phaseBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                TabView(selection: $selectedTab) {
                    FlightDashboardView(state: vm.state).tag(0)
                    FlightMapView(state: vm.state).tag(1)
                    TimesView(state: vm.state).tag(2)
                    SettingsView(relayURL: $relayURL, relayKey: $relayKey, onSave: reconnect).tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                customTabBar
            }
        }
        .onAppear { reconnect() }
    }

    private func reconnect() {
        vm.connect(url: relayURL, apiKey: relayKey)
    }

    // MARK: - Phase Reactive Background
    @ViewBuilder
    var phaseBackground: some View {
        ZStack {
            Color(hex: "#08091A")
            // Subtle radial gradient that shifts per phase
            RadialGradient(
                gradient: Gradient(colors: [phaseGlowColor.opacity(0.18), .clear]),
                center: .topTrailing,
                startRadius: 0,
                endRadius: 420
            )
            .animation(.easeInOut(duration: 2.5), value: vm.state.phase)
        }
    }

    var phaseGlowColor: Color {
        switch vm.state.phase {
        case "PREFLIGHT": return Color(hex: "#3D4A6E")
        case "TAXI":      return Color(hex: "#F59E0B")
        case "TAKEOFF":   return Color(hex: "#A855F7")
        case "CLIMB":     return Color(hex: "#4A9EFF")
        case "CRUISE":    return Color(hex: "#22D3A5")
        case "DESCENT":   return Color(hex: "#F59E0B")
        case "APPROACH":  return Color(hex: "#EF4444")
        case "LANDED":    return Color(hex: "#22D3A5")
        default:          return Color(hex: "#4A9EFF")
        }
    }

    // MARK: - Header
    var headerView: some View {
        ZStack {
            Color(hex: "#0B0F28").opacity(0.9)
                .background(.ultraThinMaterial)
            VStack(spacing: 4) {
                // Route row
                HStack(spacing: 12) {
                    Text(vm.state.simbrief?.origin.icao ?? "——")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Image(systemName: "arrow.right")
                        .foregroundColor(Color(hex: "#4A9EFF"))
                        .font(.system(size: 14, weight: .semibold))
                    Text(vm.state.simbrief?.destination.icao ?? "——")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    phasePill
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Phase timeline strip (replaces plain progress bar)
                phaseTimeline
                    .padding(.horizontal, 16)

                // Aircraft + connection row
                HStack {
                    if let ac = vm.state.simbrief?.aircraft.type {
                        Text(ac)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "#4A9EFF"))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color(hex: "#4A9EFF").opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    if let fn = vm.state.simbrief?.flightNumber, !fn.isEmpty {
                        Text(fn)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#7A8BB0"))
                    }
                    Spacer()
                    Circle()
                        .fill(vm.state.connected ? Color(hex: "#22D3A5") : Color.gray)
                        .frame(width: 7, height: 7)
                        .shadow(color: vm.state.connected ? Color(hex: "#22D3A5") : .clear, radius: 4)
                    Text(vm.state.connected ? "LIVE" : "OFFLINE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(vm.state.connected ? Color(hex: "#22D3A5") : .gray)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .frame(height: 108)
    }

    // MARK: - Phase Timeline Strip
    let allPhases = ["PREFLIGHT", "TAXI", "TAKEOFF", "CLIMB", "CRUISE", "DESCENT", "APPROACH", "LANDED"]

    var currentPhaseIndex: Int {
        allPhases.firstIndex(of: vm.state.phase) ?? 0
    }

    var phaseTimeline: some View {
        HStack(spacing: 0) {
            ForEach(Array(allPhases.enumerated()), id: \.offset) { i, phase in
                let isDone    = i < currentPhaseIndex
                let isCurrent = i == currentPhaseIndex

                HStack(spacing: 0) {
                    // Node
                    ZStack {
                        Circle()
                            .fill(isDone ? phaseColor(phase) : isCurrent ? phaseColor(phase) : Color.white.opacity(0.1))
                            .frame(width: isCurrent ? 9 : 6, height: isCurrent ? 9 : 6)
                            .shadow(color: isCurrent ? phaseColor(phase) : .clear, radius: isCurrent ? 5 : 0)
                        if isCurrent {
                            Circle()
                                .stroke(phaseColor(phase).opacity(0.4), lineWidth: 1.5)
                                .frame(width: 15, height: 15)
                        }
                    }
                    .animation(.spring(duration: 0.6), value: currentPhaseIndex)

                    // Connector line (not after last)
                    if i < allPhases.count - 1 {
                        Rectangle()
                            .fill(i < currentPhaseIndex
                                  ? LinearGradient(colors: [phaseColor(phase), phaseColor(allPhases[i+1])],
                                                   startPoint: .leading, endPoint: .trailing)
                                  : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)],
                                                   startPoint: .leading, endPoint: .trailing))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .animation(.easeInOut(duration: 0.8), value: currentPhaseIndex)
                    }
                }
            }
        }
        .frame(height: 20)
        .overlay(
            // Phase label above current node
            GeometryReader { geo in
                let nodeCount = allPhases.count
                let spacing   = geo.size.width / CGFloat(nodeCount - 1)
                let x         = CGFloat(currentPhaseIndex) * spacing
                Text(shortPhase(vm.state.phase))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(phaseColor(vm.state.phase))
                    .position(x: min(max(x, 20), geo.size.width - 20), y: -6)
            }
        )
        .padding(.top, 4)
    }

    func shortPhase(_ p: String) -> String {
        switch p {
        case "PREFLIGHT": return "PRE"
        case "TAKEOFF":   return "T/O"
        case "APPROACH":  return "APP"
        default: return p
        }
    }

    // MARK: - Phase Pill
    var phasePill: some View {
        Text(vm.state.phase)
            .font(.system(size: 9, weight: .heavy)).kerning(1.2)
            .foregroundColor(phaseColor(vm.state.phase))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(phaseColor(vm.state.phase).opacity(0.18))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(phaseColor(vm.state.phase).opacity(0.4), lineWidth: 1))
    }

    // MARK: - Tab Bar
    var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { idx, tab in
                Button {
                    withAnimation(.spring(duration: 0.3)) { selectedTab = idx }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: selectedTab == idx ? .semibold : .regular))
                        Text(tab.label)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(selectedTab == idx ? Color(hex: "#4A9EFF") : Color(hex: "#3D4A6E"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(Color(hex: "#0B0F28").opacity(0.9).background(.ultraThinMaterial))
        .overlay(Rectangle().fill(Color(hex: "#4A9EFF").opacity(0.12)).frame(height: 1), alignment: .top)
    }

    let tabs = [
        (icon: "gauge.open.with.lines.needle.33percent", label: "Dashboard"),
        (icon: "map.fill",      label: "Map"),
        (icon: "clock.fill",    label: "Times"),
        (icon: "gearshape.fill",label: "Settings")
    ]
}

// MARK: - Phase Color Helper
func phaseColor(_ phase: String) -> Color {
    switch phase {
    case "TAXI":      return Color(hex: "#F59E0B")
    case "TAKEOFF":   return Color(hex: "#A855F7")
    case "CLIMB":     return Color(hex: "#4A9EFF")
    case "CRUISE":    return Color(hex: "#22D3A5")
    case "DESCENT":   return Color(hex: "#F59E0B")
    case "APPROACH":  return Color(hex: "#EF4444")
    case "LANDED":    return Color(hex: "#22D3A5")
    default:          return Color(hex: "#4A9EFF")
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
