import SwiftUI

struct ContentView: View {
    @StateObject private var vm = FlightViewModel()
    @AppStorage("relayURL") var relayURL = "https://msfs-relay.onrender.com"
    @AppStorage("relayKey") var relayKey = "flight-companion-key"
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Color(hex: "#08091A").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Tab content
                TabView(selection: $selectedTab) {
                    FlightDashboardView(state: vm.state)
                        .tag(0)
                    FlightMapView(state: vm.state)
                        .tag(1)
                    TimesView(state: vm.state)
                        .tag(2)
                    SettingsView(relayURL: $relayURL, relayKey: $relayKey, onSave: reconnect)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Custom tab bar
                customTabBar
            }
        }
        .onAppear { reconnect() }
    }

    private func reconnect() {
        vm.connect(url: relayURL, apiKey: relayKey)
    }

    // MARK: - Header
    var headerView: some View {
        ZStack {
            Color(hex: "#0B0F28")
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

                // Progress bar
                progressBar

                // Aircraft + connection row
                HStack {
                    if let ac = vm.state.simbrief?.aircraft.type {
                        Text(ac)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "#4A9EFF"))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(hex: "#4A9EFF").opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    if let fn = vm.state.simbrief?.flightNumber, !fn.isEmpty {
                        Text(fn)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#7A8BB0"))
                    }
                    Spacer()
                    // Connection dot
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
        .frame(height: 100)
        .cornerRadius(0)
    }

    // MARK: - Progress Bar
    var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#4A9EFF"), Color(hex: "#22D3A5")]),
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: CGFloat(vm.state.progressPercent / 100) * geo.size.width, height: 6)
                    .shadow(color: Color(hex: "#4A9EFF").opacity(0.5), radius: 4)
                    .animation(.spring(duration: 1), value: vm.state.progressPercent)

                // Plane icon
                Text("✈")
                    .font(.system(size: 14))
                    .shadow(color: Color(hex: "#4A9EFF"), radius: 6)
                    .offset(x: max(0, min(CGFloat(vm.state.progressPercent / 100) * geo.size.width - 7, geo.size.width - 14)))
                    .animation(.spring(duration: 1), value: vm.state.progressPercent)
            }
        }
        .frame(height: 20)
        .padding(.horizontal, 16)
    }

    // MARK: - Phase Pill
    var phasePill: some View {
        Text(vm.state.phase)
            .font(.system(size: 9, weight: .heavy))
            .kerning(1.2)
            .foregroundColor(phaseColor(vm.state.phase))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
        .background(Color(hex: "#0B0F28"))
        .overlay(Rectangle().fill(Color(hex: "#4A9EFF").opacity(0.12)).frame(height: 1), alignment: .top)
    }

    let tabs = [
        (icon: "gauge.open.with.lines.needle.33percent", label: "Dashboard"),
        (icon: "map.fill", label: "Map"),
        (icon: "clock.fill", label: "Times"),
        (icon: "gearshape.fill", label: "Settings")
    ]
}

// MARK: - Helpers
func phaseColor(_ phase: String) -> Color {
    switch phase {
    case "TAXI":     return Color(hex: "#F59E0B")
    case "TAKEOFF":  return Color(hex: "#A855F7")
    case "CLIMB":    return Color(hex: "#4A9EFF")
    case "CRUISE":   return Color(hex: "#22D3A5")
    case "DESCENT":  return Color(hex: "#F59E0B")
    case "APPROACH": return Color(hex: "#EF4444")
    case "LANDED":   return Color(hex: "#22D3A5")
    default:         return Color(hex: "#4A9EFF")
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
