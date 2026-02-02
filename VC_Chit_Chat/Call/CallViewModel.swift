import Foundation
import WebRTC
import Combine

class CallViewModel: ObservableObject {
    @Published var status = "Disconnected"
    @Published var targetId = ""
    @Published var localTrack: RTCVideoTrack?
    @Published var remoteTrack: RTCVideoTrack?
    @Published var hasIncomingCall = false
    private var callerId: String?

    init() {
        WebRTCManager.shared.$localVideoTrack.assign(to: &$localTrack)
        WebRTCManager.shared.$remoteVideoTrack.assign(to: &$remoteTrack)
        
        SignalingManager.shared.onMessageReceived = { [weak self] dict in
            self?.handleSignal(dict)
        }
    }

    func connect() { SignalingManager.shared.connect() }
    
    func startCall() {
        status = "Calling..."
        WebRTCManager.shared.startCall(to: targetId)
    }

    func answerCall() {
        guard let id = callerId else { return }
        WebRTCManager.shared.peerConnection?.answer(for: RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveVideo": "true"], optionalConstraints: nil)) { sdp, _ in
            guard let sdp = sdp else { return }
            WebRTCManager.shared.peerConnection?.setLocalDescription(sdp) { _ in
                SignalingManager.shared.send(dict: ["type": "answer", "sdp": sdp.sdp, "target": id, "from": SignalingManager.shared.myId])
                DispatchQueue.main.async { self.hasIncomingCall = false; self.status = "Connected" }
            }
        }
    }
    func endCall() {
            // 1. Tell the server we are hanging up
            SignalingManager.shared.send(dict: ["type": "hangup", "target": targetId])
            
            // 2. Close the WebRTC connection
            WebRTCManager.shared.peerConnection?.close()
            WebRTCManager.shared.peerConnection = nil
            WebRTCManager.shared.remoteVideoTrack = nil
            
            // 3. Update the UI status
            DispatchQueue.main.async {
                self.status = "Server Connected"
                self.hasIncomingCall = false
                self.remoteTrack = nil
            }
        }

    private func handleSignal(_ dict: [String: Any]) {
        let type = dict["type"] as? String
        if type == "offer" {
            callerId = dict["from"] as? String
            WebRTCManager.shared.prepareConnection(targetId: callerId!)
            let sdp = RTCSessionDescription(type: .offer, sdp: dict["sdp"] as! String)
            WebRTCManager.shared.peerConnection?.setRemoteDescription(sdp) { _ in
                DispatchQueue.main.async { self.hasIncomingCall = true; self.status = "Incoming..." }
            }
        } else if type == "answer" {
            let sdp = RTCSessionDescription(type: .answer, sdp: dict["sdp"] as! String)
            WebRTCManager.shared.peerConnection?.setRemoteDescription(sdp) { _ in }
        } else if type == "candidate" {
            let candidate = RTCIceCandidate(sdp: dict["candidate"] as! String, sdpMLineIndex: dict["sdpMLineIndex"] as! Int32, sdpMid: dict["sdpMid"] as? String)
            WebRTCManager.shared.peerConnection?.add(candidate)
        }
    }
}
