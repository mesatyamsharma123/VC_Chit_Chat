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
    private var localAudioTrack: RTCAudioTrack? // New
    var remotePeerId: String?

    private override init() {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        self.factory = RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
        super.init()
        setupLocalMedia()
    }

    private func setupLocalMedia() {
        // Video Setup
        let videoSource = factory.videoSource()
        videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        localVideoTrack = factory.videoTrack(with: videoSource, trackId: "video0")
        
        // Audio Setup (The Audio Fix)
        let audioSource = factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        localAudioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        
        guard let device = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == .front }),
              let format = RTCCameraVideoCapturer.supportedFormats(for: device).last,
              let fps = format.videoSupportedFrameRateRanges.first?.maxFrameRate else { return }
        
        videoCapturer?.startCapture(with: device, format: format, fps: Int(fps))
    }

    // Audio routing fix for iOS
    private func configureAudioSession() {
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with: [.allowBluetooth, .defaultToSpeaker])
            try session.setMode(AVAudioSession.Mode.voiceChat.rawValue)
            try session.setActive(true)
        } catch { print("❌ Audio Session Error: \(error)") }
        session.unlockForConfiguration()
    }

    func prepareConnection(targetId: String) {
        self.remotePeerId = targetId
        configureAudioSession() // Activate speakers/mic
        
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        
        peerConnection = factory.peerConnection(with: config, constraints: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil), delegate: self)
        
        let streamId = "stream0"
        // Add both tracks
        if let vt = localVideoTrack { peerConnection?.add(vt, streamIds: [streamId]) }
        if let at = localAudioTrack { peerConnection?.add(at, streamIds: [streamId]) }
    }

    func startCall(to peerId: String) {
        prepareConnection(targetId: peerId)
        // Request both audio and video in SDP
        let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveVideo": "true", "OfferToReceiveAudio": "true"], optionalConstraints: nil)
        
        peerConnection?.offer(for: constraints) { sdp, _ in
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
        SignalingManager.shared.send(dict: ["type": "candidate", "candidate": candidate.sdp, "sdpMLineIndex": candidate.sdpMLineIndex, "sdpMid": candidate.sdpMid ?? "", "target": target, "from": SignalingManager.shared.myId])
    }
    
    func peerConnection(_ pc: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        DispatchQueue.main.async { self.remoteVideoTrack = stream.videoTracks.first }
    }
    
    // Required Stubs
    func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCSignalingState) {}
    func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCIceConnectionState) {}
    func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCIceGatheringState) {}
    func peerConnectionShouldNegotiate(_ pc: RTCPeerConnection) {}
    func peerConnection(_ pc: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnection(_ pc: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
    func peerConnection(_ pc: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
}
