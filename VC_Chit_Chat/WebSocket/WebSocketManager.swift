import Foundation
import WebRTC
import Combine


class SignalingManager: NSObject, URLSessionWebSocketDelegate, ObservableObject {
    static let shared = SignalingManager()
    @Published var isConnected = false
    let myId = "User-\(Int.random(in: 100...999))"
    var onMessageReceived: (([String: Any]) -> Void)?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let url = URL(string: "wss://9d9b977e20c4.ngrok-free.app")!

    func connect() {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receive()
    }

    func send(dict: [String: Any]) {
        var payload = dict
        payload["from"] = self.myId // ALWAYS include who sent it
        
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        
        webSocketTask?.send(.string(jsonString)) { error in
            if let error = error { print("Send Error: \(error)") }
        }
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

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.send(dict: ["type": "login", "from": self.myId])
        }
    }
}
