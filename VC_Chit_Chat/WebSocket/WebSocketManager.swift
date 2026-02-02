import Foundation
import WebRTC
import Combine

class SignalingManager: NSObject, URLSessionWebSocketDelegate, ObservableObject {
    static let shared = SignalingManager()
    @Published var isConnected = false
    
    // Generates a random ID like "User-123" so you can test two phones
    let myId = "User-\(Int.random(in: 100...999))"
    var onMessageReceived: (([String: Any]) -> Void)?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let url = URL(string: "wss://9692d2b5468b.ngrok-free.app")!

    func connect() {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receive()
    }

    func send(dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(jsonString)) { _ in }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }

    private func receive() {
        webSocketTask?.receive { [weak self] result in
            if case .success(.string(let text)) = result,
               let data = text.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                DispatchQueue.main.async { self?.onMessageReceived?(dict) }
                self?.receive()
            }
        }
    }

    // Helper methods for WebRTCManager
    func sendSDP(_ sdp: RTCSessionDescription, to peerId: String) {
        send(dict: ["type": sdp.type == .offer ? "offer" : "answer", "sdp": sdp.sdp, "target": peerId, "from": myId])
    }

    func sendCandidate(_ c: RTCIceCandidate, to peerId: String) {
        send(dict: ["type": "candidate", "candidate": c.sdp, "sdpMLineIndex": c.sdpMLineIndex, "sdpMid": c.sdpMid ?? "", "target": peerId, "from": myId])
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
            // 🔑 IMPORTANT: Register with the Node.js server
            self.send(dict: ["type": "login", "from": self.myId])
        }
    }
}
