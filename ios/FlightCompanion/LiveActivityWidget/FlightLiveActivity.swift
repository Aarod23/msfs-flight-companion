import ActivityKit
import WidgetKit
import SwiftUI

// NOTE: This file must be in the Widget Extension target in Xcode.
// The FlightActivityAttributes struct must match exactly what's in the main app.

struct FlightActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: String
        var originICAO: String
        var destICAO: String
        var remainingMinutes: Int
        var progressPercent: Double
        var altFt: Int
        var ias: Int
        var etaTimeString: String
        var connected: Bool
    }
    var flightNumber: String
    var aircraftType: String
}

// MARK: - Main Widget

@main
struct FlightLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlightActivityAttributes.self) { context in
            // Lock Screen / Notification Center view
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (long press)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("✈ \(context.attributes.flightNumber)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("\(context.state.originICAO) → \(context.state.destICAO)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.etaTimeString)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text(phaseBadge(context.state.phase))
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(phaseColor(context.state.phase))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 5)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "#4A9EFF"), Color(hex: "#22D3A5")],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .frame(width: CGFloat(context.state.progressPercent / 100) * geo.size.width, height: 5)
                                // Plane
                                Text("✈")
                                    .font(.system(size: 10))
                                    .offset(x: max(0, CGFloat(context.state.progressPercent / 100) * geo.size.width - 5))
                            }
                        }
                        .frame(height: 12)

                        HStack {
                            // Time remaining
                            let h = context.state.remainingMinutes / 60
                            let m = context.state.remainingMinutes % 60
                            Text("\(h)h \(m)m remaining")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            // Alt + IAS
                            Text("FL\(context.state.altFt / 100) · \(context.state.ias)kt")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                // Left of camera pill (compact)
                Text("✈")
                    .font(.system(size: 14))
                    .foregroundColor(phaseColor(context.state.phase))
            } compactTrailing: {
                // Right of camera pill (compact)
                let h = context.state.remainingMinutes / 60
                let m = context.state.remainingMinutes % 60
                Text("\(h)h\(m)m")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
            } minimal: {
                // Smallest — just the plane icon
                Text("✈")
                    .font(.system(size: 14))
                    .foregroundColor(phaseColor(context.state.phase))
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<FlightActivityAttributes>

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("✈ \(context.state.originICAO)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                Text(context.state.destICAO)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                Spacer()
                Text(phaseBadge(context.state.phase))
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(phaseColor(context.state.phase))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(phaseColor(context.state.phase).opacity(0.2))
                    .clipShape(Capsule())
            }
            .foregroundColor(.white)

            // Progress bar
            ProgressView(value: context.state.progressPercent, total: 100)
                .tint(Color(hex: "#4A9EFF"))
                .scaleEffect(x: 1, y: 1.5, anchor: .center)

            HStack {
                let h = context.state.remainingMinutes / 60
                let m = context.state.remainingMinutes % 60
                Text("\(h)h \(m)m remaining")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("ETA \(context.state.etaTimeString)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }

            HStack {
                Text("FL\(context.state.altFt / 100)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                Text("·")
                    .foregroundColor(.gray)
                Text("\(context.state.ias)kt")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Text(context.attributes.aircraftType)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#4A9EFF"))
            }
        }
        .padding(14)
        .background(Color(hex: "#08091A"))
    }
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

func phaseBadge(_ phase: String) -> String {
    switch phase {
    case "PREFLIGHT": return "PRE"
    case "TAXI":      return "TAXI"
    case "TAKEOFF":   return "T/O"
    case "CLIMB":     return "CLB"
    case "CRUISE":    return "CRZ"
    case "DESCENT":   return "DES"
    case "APPROACH":  return "APP"
    case "LANDED":    return "LND"
    default:          return phase
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
