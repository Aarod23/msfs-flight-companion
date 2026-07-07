import Foundation

class RelayClient {
    var onStateUpdate: ((FlightState) -> Void)?

    private let serverURL: String
    private let apiKey: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectTimer: Timer?
    private var isRunning = false

    init(serverURL: String, apiKey: String) {
        self.serverURL = serverURL
        self.apiKey = apiKey
    }

    func start() {
        isRunning = true
        // First fetch current state via REST
        fetchState()
        // Then open WebSocket for live updates
        connectWebSocket()
    }

    func stop() {
        isRunning = false
        reconnectTimer?.invalidate()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - REST Fetch (on connect)
    func fetchState() {
        guard let url = URL(string: "\(serverURL)/state") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            if let state = try? JSONDecoder().decode(FlightState.self, from: data) {
                DispatchQueue.main.async { self?.onStateUpdate?(state) }
            }
        }.resume()
    }

    // MARK: - WebSocket (live updates)
    func connectWebSocket() {
        guard isRunning else { return }
        let wsURLString = serverURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        guard let url = URL(string: wsURLString) else { return }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 10

        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        receiveMessage()
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                default: break
                }
                self.receiveMessage() // keep listening
            case .failure:
                self.scheduleReconnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        struct WSMessage: Codable {
            let type: String
            let data: FlightState?
        }

        if let msg = try? JSONDecoder().decode(WSMessage.self, from: data),
           msg.type == "state", let state = msg.data {
            DispatchQueue.main.async { self.onStateUpdate?(state) }
        }
    }

    private func scheduleReconnect() {
        guard isRunning else { return }
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.connectWebSocket()
        }
    }
}
