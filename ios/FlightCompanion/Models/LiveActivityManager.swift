import ActivityKit
import SwiftUI

// MARK: - Activity Attributes
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

// MARK: - Live Activity Manager
class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<FlightActivityAttributes>?

    /// Returns nil on success, or an error string to display to the user.
    @discardableResult
    func start(state: FlightState) -> String? {
        let info = ActivityAuthorizationInfo()

        guard info.areActivitiesEnabled else {
            return "Live Activities are not enabled for this app.\n\nGo to Settings → Flight Companion → Live Activities and turn it on."
        }

        // End any currently running activity first
        if let existing = currentActivity {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
            currentActivity = nil
        }

        let attrs = FlightActivityAttributes(
            flightNumber: state.simbrief?.flightNumber ?? "MSFS",
            aircraftType: state.simbrief?.aircraft.type ?? "ACFT"
        )
        let contentState = makeContentState(from: state)

        do {
            let activity = try Activity<FlightActivityAttributes>.request(
                attributes: attrs,
                content: .init(state: contentState, staleDate: Date().addingTimeInterval(60)),
                pushType: nil
            )
            currentActivity = activity
            print("[LiveActivity] Started: \(activity.id)")
            return nil // success
        } catch {
            print("[LiveActivity] Failed: \(error)")
            return "Could not start Dynamic Island.\n\nError: \(error.localizedDescription)\n\nMake sure you're running on a physical iPhone 14 Pro or later with iOS 16.1+."
        }
    }

    func update(state: FlightState) {
        guard let activity = currentActivity else {
            // Auto-start when flight is active and we have data
            if state.connected && state.phase != "PREFLIGHT" && state.phase != "LANDED" {
                _ = start(state: state)
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

    var isActive: Bool { currentActivity != nil }

    private func makeContentState(from state: FlightState) -> FlightActivityAttributes.ContentState {
        let eta = state.etaDate
        let remainingMinutes = eta.map { max(0, Int($0.timeIntervalSinceNow / 60)) } ?? 0

        let etaStr: String
        if let eta {
            let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: "UTC")
            etaStr = f.string(from: eta) + "Z"
        } else {
            etaStr = "——:——"
        }

        return FlightActivityAttributes.ContentState(
            phase:            state.phase,
            originICAO:       state.simbrief?.origin.icao      ?? "——",
            destICAO:         state.simbrief?.destination.icao ?? "——",
            remainingMinutes: remainingMinutes,
            progressPercent:  state.progressPercent,
            altFt:            Int(state.alt),
            ias:              Int(state.ias),
            etaTimeString:    etaStr,
            connected:        state.connected
        )
    }
}
