import SwiftUI

// ─────────────────────────────────────────────────────────────
// MARK: - Root Content View
// Full-screen map + draggable bottom sheet overlay
// ─────────────────────────────────────────────────────────────
struct ContentView: View {
    @StateObject private var vm = FlightViewModel()
    @AppStorage("relayURL") var relayURL = "https://msfs-relay.onrender.com"
    @AppStorage("relayKey") var relayKey  = "flight-companion-key"

    // Sheet snap positions
    private let snapCollapsed: CGFloat = 310
    private let snapExpanded:  CGFloat = 620

    @State private var sheetHeight: CGFloat = 310
    @State private var dragOffset:  CGFloat = 0
    @State private var showSettings = false
    @State private var showTimes    = false
    @State private var laError: String?  = nil
    @State private var showLAError  = false
    @State private var laActive     = false

    var currentSheetHeight: CGFloat {
        min(max(sheetHeight + dragOffset, snapCollapsed - 60), snapExpanded + 30)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            // ── Full-screen map ──────────────────────────────
            MapKitView(state: vm.state, followAircraft: .constant(true))
                .ignoresSafeArea()

            // ── Bottom scrim ─────────────────────────────────
            LinearGradient(colors: [.clear, Color.black.opacity(0.7)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 200)
                .allowsHitTesting(false)

            // ── Top connection badge ──────────────────────────
            VStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(vm.state.connected ? Color(hex: "#00C853") : Color(hex: "#444"))
                        .frame(width: 7, height: 7)
                        .shadow(color: vm.state.connected ? Color(hex: "#00C853") : .clear, radius: 4)
                    Text(vm.state.connected ? "MSFS CONNECTED" : "WAITING FOR MSFS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(vm.state.connected ? Color(hex: "#00C853") : Color(hex: "#444"))
                    Spacer()
                    if vm.state.connected {
                        phasePill(vm.state.phase)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                Spacer()
            }

            // ── Bottom sheet ─────────────────────────────────
            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                FlightSheetContent(
                    vm: vm,
                    isExpanded: currentSheetHeight > (snapCollapsed + 80),
                    laActive: $laActive,
                    onStartLA:  { startLiveActivity() },
                    onEndLA:    { endLiveActivity() },
                    onSettings: { showSettings = true },
                    onTimes:    { showTimes    = true }
                )
            }
            .frame(height: currentSheetHeight)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 28, topTrailingRadius: 28,
                    bottomLeadingRadius: 0, bottomTrailingRadius: 0,
                    style: .continuous
                )
                .fill(Color(hex: "#0D0D0D"))
                .shadow(color: .black.opacity(0.9), radius: 40, y: -10)
            )
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { v in dragOffset = -v.translation.height }
                    .onEnded   { v in
                        let velocity = -v.predictedEndTranslation.height
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.76)) {
                            let threshold = (snapExpanded - snapCollapsed) / 2.5
                            sheetHeight = (velocity > 250 || dragOffset > threshold)
                                ? snapExpanded : snapCollapsed
                            dragOffset = 0
                        }
                    }
            )
        }
        .ignoresSafeArea()
        .onAppear { vm.connect(url: relayURL, apiKey: relayKey) }
        .sheet(isPresented: $showSettings) {
            SettingsView(relayURL: $relayURL, relayKey: $relayKey,
                         onSave: { vm.connect(url: relayURL, apiKey: relayKey) })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTimes) {
            TimesView(state: vm.state)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Dynamic Island", isPresented: $showLAError, actions: {
            Button("OK", role: .cancel) {}
            Button("Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        }, message: {
            Text(laError ?? "Could not start Live Activity.")
        })
    }

    // MARK: - Live Activity
    private func startLiveActivity() {
        let error = LiveActivityManager.shared.start(state: vm.state)
        if let error {
            laError     = error
            showLAError = true
        } else {
            withAnimation(.spring(duration: 0.3)) { laActive = true }
        }
    }

    private func endLiveActivity() {
        LiveActivityManager.shared.end()
        withAnimation(.spring(duration: 0.3)) { laActive = false }
    }
}

// MARK: - Phase Pill Helper
func phasePill(_ phase: String) -> some View {
    Text(phase)
        .font(.system(size: 9, weight: .black)).kerning(1.2)
        .foregroundColor(phaseColor(phase))
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(phaseColor(phase).opacity(0.15))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(phaseColor(phase).opacity(0.4), lineWidth: 1))
}

// MARK: - Phase Color
func phaseColor(_ phase: String) -> Color {
    switch phase {
    case "TAXI":      return Color(hex: "#FFC107")
    case "TAKEOFF":   return Color(hex: "#AB47BC")
    case "CLIMB":     return Color(hex: "#42A5F5")
    case "CRUISE":    return Color(hex: "#00C853")
    case "DESCENT":   return Color(hex: "#FFA726")
    case "APPROACH":  return Color(hex: "#EF5350")
    case "LANDED":    return Color(hex: "#00C853")
    default:          return Color(hex: "#42A5F5")
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8)*17, (int >> 4 & 0xF)*17, (int & 0xF)*17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255,
                  blue: Double(b)/255, opacity: Double(a)/255)
    }
}
