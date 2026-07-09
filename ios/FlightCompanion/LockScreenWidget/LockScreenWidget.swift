import WidgetKit
import SwiftUI

// ─────────────────────────────────────────────────────────────
// MARK: - Lock Screen Widget
// Shows current flight phase + ETA + progress on the lock screen
// ─────────────────────────────────────────────────────────────

struct LockScreenEntry: TimelineEntry {
    let date: Date
    let phase: String
    let originICAO: String
    let destICAO: String
    let progressPercent: Double
    let etaString: String
    let nmRemaining: Int
    let connected: Bool
}

// MARK: - Provider
struct LockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenEntry {
        LockScreenEntry(date: .now, phase: "CRUISE",
                        originICAO: "KJFK", destICAO: "KLAX",
                        progressPercent: 65, etaString: "18:42Z",
                        nmRemaining: 1240, connected: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
        // Widget reads from UserDefaults shared app group
        let entry = loadEntry()
        // Refresh every 5 minutes
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> LockScreenEntry {
        let defaults = UserDefaults(suiteName: "group.com.aarod23.FlightCompanion") ?? .standard
        return LockScreenEntry(
            date: .now,
            phase:           defaults.string(forKey: "wg_phase")       ?? "——",
            originICAO:      defaults.string(forKey: "wg_origin")      ?? "——",
            destICAO:        defaults.string(forKey: "wg_dest")        ?? "——",
            progressPercent: defaults.double(forKey: "wg_progress"),
            etaString:       defaults.string(forKey: "wg_eta")         ?? "——:——Z",
            nmRemaining:     defaults.integer(forKey: "wg_nm"),
            connected:       defaults.bool(forKey: "wg_connected")
        )
    }
}

// MARK: - Widget Views

// Rectangular lock screen widget (widest)
struct LockScreenRectView: View {
    let entry: LockScreenEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("✈ \(entry.originICAO) → \(entry.destICAO)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                Spacer()
                Text(entry.phase)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(phaseWidgetColor(entry.phase))
            }
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.15)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(.white)
                        .frame(width: CGFloat(entry.progressPercent / 100) * geo.size.width, height: 4)
                }
            }
            .frame(height: 4)
            HStack {
                Text("\(entry.nmRemaining) NM")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                Spacer()
                Text("ETA \(entry.etaString)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
            }
        }
        .foregroundColor(.white)
    }
}

// Circular lock screen widget
struct LockScreenCircleView: View {
    let entry: LockScreenEntry
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: CGFloat(entry.progressPercent / 100))
                .rotation(.degrees(-90))
                .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            VStack(spacing: 1) {
                Text("✈")
                    .font(.system(size: 14))
                Text(shortPhase(entry.phase))
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(.white)
        }
    }
}

// Inline lock screen widget (top of lock screen)
struct LockScreenInlineView: View {
    let entry: LockScreenEntry
    var body: some View {
        HStack(spacing: 4) {
            Text("✈")
            Text("\(entry.originICAO)→\(entry.destICAO)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Text("ETA \(entry.etaString)")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.white)
    }
}

// MARK: - Widget Configuration
struct FlightLockScreenWidget: Widget {
    static let kind = "FlightLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: LockScreenProvider()) { entry in
            if #available(iOSApplicationExtension 16.0, *) {
                LockScreenRectView(entry: entry)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                LockScreenRectView(entry: entry)
            }
        }
        .configurationDisplayName("Flight Progress")
        .description("Shows your current flight phase and ETA on the lock screen.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}

// MARK: - Helpers
func phaseWidgetColor(_ phase: String) -> Color {
    switch phase {
    case "CLIMB":    return .blue
    case "CRUISE":   return .green
    case "DESCENT":  return .yellow
    case "APPROACH": return .red
    default:         return .white
    }
}

func shortPhase(_ p: String) -> String {
    switch p {
    case "PREFLIGHT": return "PRE"
    case "TAKEOFF":   return "T/O"
    case "APPROACH":  return "APP"
    case "LANDED":    return "LND"
    default: return String(p.prefix(3))
    }
}
