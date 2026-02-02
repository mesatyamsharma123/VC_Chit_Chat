import Foundation
import WebRTC
import Combine

class CallViewModel: ObservableObject {
    @Published var status = "Disconnected"
    @Published var targetId = ""
    @Published var localTrack: RTCVideoTrack?
    @Published var remoteTrack: RTCVideoTrack?
    @Published var hasIncomingCall = false
    private var activeRemoteId: String?

    init() {
        WebRTCManager.shared.$localVideoTrack.assign(to: &$localTrack)
        WebRTCManager.shared.$remoteVideoTrack.assign(to: &$remoteTrack)
        SignalingManager.shared.onMessageReceived = { [weak self] dict in self?.handleSignal(dict) }
    }

    func connect() { SignalingManager.shared.connect() }
    
    func startCall() {
        // Fix: Auto-prepend "User-" if not present
        let fullId = targetId.hasPrefix("User-") ? targetId : "User-\(targetId)"
        status = "Calling..."
        WebRTCManager.shared.startCall(to: fullId)
    }

    func answerCall() {
        guard let id = activeRemoteId else { return }
        // Fix: Added Audio to constraints
        let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveVideo": "true", "OfferToReceiveAudio": "true"], optionalConstraints: nil)
        
        WebRTCManager.shared.peerConnection?.answer(for: constraints) { sdp, _ in
            guard let sdp = sdp else { return }
            WebRTCManager.shared.peerConnection?.setLocalDescription(sdp) { _ in
                SignalingManager.shared.send(dict: ["type": "answer", "sdp": sdp.sdp, "target": id, "from": SignalingManager.shared.myId])
                DispatchQueue.main.async { self.hasIncomingCall = false; self.status = "Connected" }
            }
        }
    }

    func endCall() {
        WebRTCManager.shared.peerConnection?.close()
        WebRTCManager.shared.peerConnection = nil
        DispatchQueue.main.async {
            self.status = "Server Connected"
            self.hasIncomingCall = false
            self.remoteTrack = nil
        }
    }

    private func handleSignal(_ dict: [String: Any]) {
        guard let type = dict["type"] as? String else { return }
        switch type {
        case "offer":
            activeRemoteId = dict["from"] as? String
            WebRTCManager.shared.prepareConnection(targetId: activeRemoteId!)
            let sdp = RTCSessionDescription(type: .offer, sdp: dict["sdp"] as! String)
            WebRTCManager.shared.peerConnection?.setRemoteDescription(sdp) { _ in
                DispatchQueue.main.async { self.hasIncomingCall = true; self.status = "Incoming..." }
            }
        case "answer":
            let sdp = RTCSessionDescription(type: .answer, sdp: dict["sdp"] as! String)
            WebRTCManager.shared.peerConnection?.setRemoteDescription(sdp) { _ in
                DispatchQueue.main.async { self.status = "Connected" }
            }
        case "candidate":
            let candidate = RTCIceCandidate(sdp: dict["candidate"] as! String, sdpMLineIndex: dict["sdpMLineIndex"] as! Int32, sdpMid: dict["sdpMid"] as? String)
            WebRTCManager.shared.peerConnection?.add(candidate)
        case "hangup": self.endCall()
        default: break
        }
    }
}
