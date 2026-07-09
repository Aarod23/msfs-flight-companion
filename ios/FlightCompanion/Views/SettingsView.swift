import SwiftUI

struct SettingsView: View {
    @Binding var relayURL: String
    @Binding var relayKey: String
    let onSave: () -> Void

    @State private var editURL = ""
    @State private var editKey = ""
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Logo
                VStack(spacing: 6) {
                    Text("✈")
                        .font(.system(size: 48))
                    Text("Flight Companion")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("MSFS 2024 + SimBrief")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#7A8BB0"))
                }
                .padding(.top, 20)

                // Server config
                settingsCard(title: "RELAY SERVER") {
                    VStack(alignment: .leading, spacing: 12) {
                        settingsField(label: "Server URL", placeholder: "https://your-relay.onrender.com", text: $editURL)
                        settingsField(label: "API Key",    placeholder: "flightapp2024",            text: $editKey)

                        Text("Deploy the relay server from the FlightApp/server folder to Render.com (free). Your PC desktop app sends data there, and this app reads it.")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#3D4A6E"))
                            .lineLimit(nil)

                        Button {
                            relayURL = editURL.isEmpty ? relayURL : editURL
                            relayKey = editKey.isEmpty ? relayKey : editKey
                            onSave()
                            saved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                        } label: {
                            Text(saved ? "✓ Saved" : "Save & Reconnect")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(saved ? Color(hex: "#22D3A5") : Color(hex: "#4A9EFF"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background((saved ? Color(hex: "#22D3A5") : Color(hex: "#4A9EFF")).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // SimBrief info
                settingsCard(title: "SIMBRIEF") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pilot ID")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#7A8BB0"))
                            Text("1246391")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: "#22D3A5"))
                            .font(.system(size: 24))
                    }
                    Text("Click 'Load SimBrief Plan' on the desktop app to pull your latest OFP. It will automatically appear here.")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#3D4A6E"))
                }

                // Setup guide
                settingsCard(title: "SETUP GUIDE") {
                    VStack(alignment: .leading, spacing: 10) {
                        setupStep(n: 1, text: "Deploy FlightApp/server to Render.com (free)")
                        setupStep(n: 2, text: "Run FlightApp on your Windows PC (npm start)")
                        setupStep(n: 3, text: "Launch MSFS 2024 — app auto-connects")
                        setupStep(n: 4, text: "Load SimBrief plan on the desktop app")
                        setupStep(n: 5, text: "Open this app — data appears automatically")
                        setupStep(n: 6, text: "Tap 'Start Dynamic Island' on the Dashboard")
                    }
                }

                // AltStore info
                settingsCard(title: "APP INSTALL (ALTSTORE)") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("To keep this app installed on your iPhone without an Apple Developer account:")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#7A8BB0"))

                        setupStep(n: 1, text: "Install AltServer on your Windows PC")
                        setupStep(n: 2, text: "Install AltStore on your iPhone via AltServer")
                        setupStep(n: 3, text: "Open AltStore → enable Background Refresh")
                        setupStep(n: 4, text: "AltServer auto-refreshes the app every 7 days while your PC is on and iPhone is on same WiFi")
                    }
                }

                Text("MSFS Flight Companion v1.0\nBuilt with SimConnect + SimBrief")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#3D4A6E"))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 30)
            }
        }
        .background(Color(hex: "#08091A"))
        .onAppear {
            editURL = relayURL
            editKey = relayKey
        }
    }

    @ViewBuilder
    func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .kerning(1.2)
                .foregroundColor(Color(hex: "#7A8BB0"))
            content()
        }
        .padding(16)
        .background(Color(hex: "#0E1230").opacity(0.85))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    func settingsField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#7A8BB0"))
            TextField(placeholder, text: text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#4A9EFF").opacity(0.2), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    func setupStep(n: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: "#4A9EFF"))
                .frame(width: 18, height: 18)
                .background(Color(hex: "#4A9EFF").opacity(0.15))
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#7A8BB0"))
                .lineLimit(nil)
            Spacer()
        }
    }
}
