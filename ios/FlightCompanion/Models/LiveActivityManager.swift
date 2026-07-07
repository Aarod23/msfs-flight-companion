import ActivityKit
import SwiftUI

// MARK: - Activity Attributes (must match Widget Extension)

struct FlightActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: String
        var originICAO: String
        var destICAO: String
        var remainingMinutes: Int
        var progressPercent: Double
        var altFt: Int
        var ias: Int
        var etaTimeString: String   // "18:42Z"
        var connected: Bool
    }

    var flightNumber: String
    var aircraftType: String
}

// MARK: - Live Activity Manager

class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<FlightActivityAttributes>?
    private var lastPhase = ""

    func start(state: FlightState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Activities not enabled")
            return
        }

        let attrs = FlightActivityAttributes(
            flightNumber: state.simbrief?.flightNumber ?? "MSFS",
            aircraftType: state.simbrief?.aircraft.type ?? "ACFT"
        )
        let contentState = makeContentState(from: state)

        do {
            let activity = try Activity<FlightActivityAttributes>.request(
                attributes: attrs,
                content: .init(state: contentState, staleDate: Date().addingTimeInterval(60))
            )
            currentActivity = activity
            print("[LiveActivity] Started: \(activity.id)")
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    func update(state: FlightState) {
        guard let activity = currentActivity else {
            // Auto-start when we have data and flight is active
            if state.connected && state.phase != "PREFLIGHT" {
                start(state: state)
            }
            return
        }

        let contentState = makeContentState(from: state)
        Task {
            await activity.update(.init(
                state: contentState,
                staleDate: Date().addingTimeInterval(60)
            ))
        }
    }

    func end() {
        Task {
            await currentActivity?.end(nil, dismissalPolicy: .after(Date().addingTimeInterval(30)))
            currentActivity = nil
        }
    }

    private func makeContentState(from state: FlightState) -> FlightActivityAttributes.ContentState {
        let eta = state.etaDate
        let remainingSeconds = eta.map { $0.timeIntervalSinceNow } ?? 0
        let remainingMinutes = max(0, Int(remainingSeconds / 60))

        let etaStr: String
        if let eta = eta {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            formatter.timeZone = TimeZone(identifier: "UTC")
            etaStr = formatter.string(from: eta) + "Z"
        } else {
            etaStr = "——:——"
        }

        return FlightActivityAttributes.ContentState(
            phase: state.phase,
            originICAO: state.simbrief?.origin.icao ?? "——",
            destICAO: state.simbrief?.destination.icao ?? "——",
            remainingMinutes: remainingMinutes,
            progressPercent: state.progressPercent,
            altFt: Int(state.alt),
            ias: Int(state.ias),
            etaTimeString: etaStr,
            connected: state.connected
        )
    }
}
