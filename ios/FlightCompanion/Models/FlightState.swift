import Foundation
import Combine
import UIKit
import WidgetKit
import ActivityKit


// MARK: - Data Models

struct Airport: Codable {
    var icao: String
    var name: String
    var lat: Double
    var lon: Double
    var rwy: String?
}

struct Aircraft: Codable {
    var type: String
    var reg: String?
    var name: String?
}

struct FlightTimes: Codable {
    var std: String?  // ISO8601
    var sta: String?
    var ete: Int?     // seconds
    var blockTime: Int?
}

struct FuelData: Codable {
    var units: String
    var block: Int
    var trip: Int
    var taxi: Int?
    var reserve: Int
}

struct Waypoint: Codable {
    var ident: String
    var lat: Double
    var lon: Double
    var alt: Int?
    var type: String?
}

struct SimBriefPlan: Codable {
    var origin: Airport
    var destination: Airport
    var aircraft: Aircraft
    var times: FlightTimes
    var fuel: FuelData
    var cruiseAlt: Int
    var cruiseSpeed: String?
    var route: String?
    var waypoints: [Waypoint]
    var flightNumber: String?
}

struct FlightState: Codable {
    var connected: Bool
    var phase: String
    var lat: Double
    var lon: Double
    var alt: Double
    var ias: Double
    var tas: Double?
    var gs: Double
    var hdg: Double
    var vs: Double
    var onGround: Bool
    var fuel: Double
    var engineOn: Bool
    // Wind data (from SimConnect AMBIENT WIND VELOCITY / DIRECTION)
    var windSpeed: Double
    var windDir: Double    // degrees true
    var simbrief: SimBriefPlan?
    var atd: Double?        // unix ms
    var blockOn: Double?
    var lastUpdated: Double?
    var stale: Bool?
    var serverTime: Double?

    // MARK: - Computed
    var phase_display: String { phase }

    /// Headwind component in knots (positive = headwind, negative = tailwind)
    var headwindKt: Double {
        guard windSpeed > 0, gs > 0 else { return 0 }
        let relAngle = (windDir - hdg + 360).truncatingRemainder(dividingBy: 360)
        return windSpeed * cos(relAngle * .pi / 180)
    }

    /// Crosswind component magnitude in knots
    var crosswindKt: Double {
        guard windSpeed > 0 else { return 0 }
        let relAngle = (windDir - hdg + 360).truncatingRemainder(dividingBy: 360)
        return abs(windSpeed * sin(relAngle * .pi / 180))
    }

    var etaDate: Date? {
        guard gs > 30, let sb = simbrief else { return nil }
        let distNm = greatCircleDistanceNm(lat1: lat, lon1: lon,
                                           lat2: sb.destination.lat, lon2: sb.destination.lon)
        let seconds = (distNm / gs) * 3600
        return Date().addingTimeInterval(seconds)
    }

    var progressPercent: Double {
        guard let sb = simbrief else { return 0 }
        let total = greatCircleDistanceNm(lat1: sb.origin.lat, lon1: sb.origin.lon,
                                          lat2: sb.destination.lat, lon2: sb.destination.lon)
        let flown = greatCircleDistanceNm(lat1: sb.origin.lat, lon1: sb.origin.lon,
                                          lat2: lat, lon2: lon)
        guard total > 0 else { return 0 }
        return min(100, max(0, (flown / total) * 100))
    }

    var atdDate: Date? {
        guard let ms = atd else { return nil }
        return Date(timeIntervalSince1970: ms / 1000)
    }
}

func greatCircleDistanceNm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let R = 3440.065
    let φ1 = lat1 * .pi / 180, φ2 = lat2 * .pi / 180
    let Δφ = (lat2 - lat1) * .pi / 180
    let Δλ = (lon2 - lon1) * .pi / 180
    let a = sin(Δφ/2) * sin(Δφ/2) + cos(φ1) * cos(φ2) * sin(Δλ/2) * sin(Δλ/2)
    return R * 2 * atan2(sqrt(a), sqrt(1 - a))
}

// MARK: - Flight State View Model

@MainActor
class FlightViewModel: ObservableObject {
    @Published var state: FlightState = FlightState(
        connected: false, phase: "PREFLIGHT",
        lat: 0, lon: 0, alt: 0, ias: 0, tas: 0,
        gs: 0, hdg: 0, vs: 0, onGround: true, fuel: 0, engineOn: false,
        windSpeed: 0, windDir: 0
    )
    @Published var isConnecting = false
    @Published var lastKnownPhase = "PREFLIGHT"

    private var relayClient: RelayClient?
    private var notifier = NotificationManager()

    func connect(url: String, apiKey: String) {
        relayClient = RelayClient(serverURL: url, apiKey: apiKey)
        relayClient?.onStateUpdate = { [weak self] newState in
            Task { @MainActor in
                guard let self else { return }
                let prevPhase = self.state.phase
                self.state = newState
                if prevPhase != newState.phase {
                    self.handlePhaseChange(from: prevPhase, to: newState.phase)
                }
                self.updateLiveActivity(newState)
            }
        }
        relayClient?.start()
    }

    private func handlePhaseChange(from prev: String, to next: String) {
        // Haptic feedback
        let style: UIImpactFeedbackGenerator.FeedbackStyle = next == "LANDED" ? .heavy :
            (next == "TAKEOFF" || next == "APPROACH") ? .medium : .light
        UIImpactFeedbackGenerator(style: style).impactOccurred()

        let messages: [String: (String, String)] = [
            "TAKEOFF":  ("✈️ Takeoff Roll", "Aircraft is accelerating for takeoff"),
            "CLIMB":    ("🔝 Climbing", "Climbing to cruise altitude"),
            "CRUISE":   ("🛫 Cruise", "Reached cruise altitude - have a great flight!"),
            "DESCENT":  ("🛬 Descending", "Beginning descent to destination"),
            "APPROACH": ("⏰ On Approach", "Approaching the destination airport"),
            "LANDED":   ("🏁 Landed", blockTimeMessage())
        ]
        if let (title, body) = messages[next] {
            notifier.send(title: title, body: body)
        }
    }

    private func blockTimeMessage() -> String {
        guard let atd = state.atdDate else { return "Touchdown!" }
        let elapsed = Date().timeIntervalSince(atd)
        let h = Int(elapsed / 3600), m = Int(elapsed.truncatingRemainder(dividingBy: 3600) / 60)
        return "Block time: \(h)h \(m)m"
    }

    private func updateLiveActivity(_ s: FlightState) {
        // LiveActivityManager handles authorization check internally
        LiveActivityManager.shared.update(state: s)
        writeWidgetData(s)
    }

    /// Push current state to shared UserDefaults so the lock screen widget can read it
    private func writeWidgetData(_ s: FlightState) {
        let defaults = UserDefaults(suiteName: "group.com.aarod23.FlightCompanion") ?? .standard
        defaults.set(s.phase,   forKey: "wg_phase")
        defaults.set(s.simbrief?.origin.icao      ?? "——", forKey: "wg_origin")
        defaults.set(s.simbrief?.destination.icao ?? "——", forKey: "wg_dest")
        defaults.set(s.progressPercent,            forKey: "wg_progress")
        defaults.set(s.connected,                  forKey: "wg_connected")

        // ETA string
        if let eta = s.etaDate {
            let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: "UTC")
            defaults.set(f.string(from: eta) + "Z", forKey: "wg_eta")
        } else {
            defaults.set("——:——Z", forKey: "wg_eta")
        }

        // NM remaining
        if let sb = s.simbrief, s.lat != 0 {
            let nm = greatCircleDistanceNm(lat1: s.lat, lon1: s.lon,
                                           lat2: sb.destination.lat, lon2: sb.destination.lon)
            defaults.set(Int(nm), forKey: "wg_nm")
        }

        // Tell WidgetKit to reload
        WidgetCenter.shared.reloadTimelines(ofKind: "FlightLockScreenWidget")
    }


    func startLiveActivity() {
        _ = LiveActivityManager.shared.start(state: state)
    }
}
