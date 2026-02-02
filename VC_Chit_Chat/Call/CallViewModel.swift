import Foundation
import WebRTC
import Combine

class CallViewModel: ObservableObject {
    @Published var status: String = "Disconnected"
    @Published var hasIncomingCall: Bool = false
    
    @Published var localTrack: RTCVideoTrack?
    @Published var remoteTrack: RTCVideoTrack?
    
    private var remotePeerId: String? // Store who is calling us
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Link Tracks from WebRTCManager
        WebRTCManager.shared.$localVideoTrack.assign(to: &$localTrack)
        WebRTCManager.shared.$remoteVideoTrack.assign(to: &$remoteTrack)
        
        // Setup Signaling Listeners
        SignalingManager.shared.onMessageReceived = { [weak self] dict in
            self?.handleIncomingSignal(dict)
        }
        
        // Watch Connection State
        SignalingManager.shared.$isConnected
            .map { $0 ? "Server Connected" : "Disconnected" }
            .assign(to: &$status)
    }

    func connect() {
        SignalingManager.shared.connect()
    }

    func startCall() {
        // For testing, we use a placeholder "target_id".
        // In a real app, you'd get this from a list of users.
        self.status = "Calling..."
        WebRTCManager.shared.startCall(to: "target_user_id")
    }

    func answerCall() {
        guard let peerId = remotePeerId else { return }
        self.status = "Audio Connected!"
        self.hasIncomingCall = false
        // The handleRemoteOffer logic in WebRTCManager handles the rest
    }

    func endCall() {
        SignalingManager.shared.disconnect()
        self.status = "Disconnected"
        self.hasIncomingCall = false
    }

    private func handleIncomingSignal(_ dict: [String: Any]) {
        guard let type = dict["type"] as? String else { return }
        
        switch type {
        case "offer":
            self.status = "Incoming Call..."
            self.hasIncomingCall = true
            self.remotePeerId = dict["from"] as? String
            
            // Auto-prepare WebRTC but wait for user to press "Answer"
            if let sdp = dict["sdp"] as? String, let from = remotePeerId {
                let offer = RTCSessionDescription(type: .offer, sdp: sdp)
                WebRTCManager.shared.handleRemoteOffer(offer, from: from)
            }
            
        case "candidate":
            WebRTCManager.shared.addIceCandidate(parseCandidate(dict))
        default: break
        }
    }
    
    private func parseCandidate(_ dict: [String: Any]) -> RTCIceCandidate {
        return RTCIceCandidate(
            sdp: dict["candidate"] as! String,
            sdpMLineIndex: dict["sdpMLineIndex"] as! Int32,
            sdpMid: dict["sdpMid"] as? String
        )
    }
}
