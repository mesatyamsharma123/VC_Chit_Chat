import Foundation
import WebRTC
import Combine

final class WebRTCManager: NSObject, ObservableObject {
    static let shared = WebRTCManager()
    @Published var localVideoTrack: RTCVideoTrack?
    @Published var remoteVideoTrack: RTCVideoTrack?
    
    private let factory: RTCPeerConnectionFactory
    var peerConnection: RTCPeerConnection?
    private var videoCapturer: RTCCameraVideoCapturer?
    private var remotePeerId: String?

    private override init() {
        RTCInitializeSSL()
        self.factory = RTCPeerConnectionFactory(encoderFactory: RTCDefaultVideoEncoderFactory(), decoderFactory: RTCDefaultVideoDecoderFactory())
        super.init()
        setupLocalMedia()
    }

    private func setupLocalMedia() {
        let source = factory.videoSource()
        videoCapturer = RTCCameraVideoCapturer(delegate: source)
        localVideoTrack = factory.videoTrack(with: source, trackId: "video0")
        
        if let device = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == .front }),
           let format = RTCCameraVideoCapturer.supportedFormats(for: device).last,
           let fps = format.videoSupportedFrameRateRanges.first?.maxFrameRate {
            videoCapturer?.startCapture(with: device, format: format, fps: Int(fps))
        }
    }

    func prepareConnection(targetId: String) {
        self.remotePeerId = targetId
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        peerConnection = factory.peerConnection(with: config, constraints: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil), delegate: self)
        
        if let local = localVideoTrack { peerConnection?.add(local, streamIds: ["stream0"]) }
    }

    func startCall(to peerId: String) {
        prepareConnection(targetId: peerId)
        peerConnection?.offer(for: RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveVideo": "true"], optionalConstraints: nil)) { sdp, _ in
            guard let sdp = sdp else { return }
            self.peerConnection?.setLocalDescription(sdp) { _ in
                SignalingManager.shared.send(dict: ["type": "offer", "sdp": sdp.sdp, "target": peerId, "from": SignalingManager.shared.myId])
            }
        }
    }
}

extension WebRTCManager: RTCPeerConnectionDelegate {
    func peerConnection(_ pc: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        guard let target = remotePeerId else { return }
        SignalingManager.shared.send(dict: ["type": "candidate", "candidate": candidate.sdp, "sdpMLineIndex": candidate.sdpMLineIndex, "sdpMid": candidate.sdpMid ?? "", "target": target])
    }
    func peerConnection(_ pc: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        DispatchQueue.main.async { self.remoteVideoTrack = stream.videoTracks.first }
    }
    // Stubs
    func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCSignalingState) {}
    func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCIceConnectionState) {}
    func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCIceGatheringState) {}
    func peerConnectionShouldNegotiate(_ pc: RTCPeerConnection) {}
    func peerConnection(_ pc: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnection(_ pc: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
    func peerConnection(_ pc: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
}
