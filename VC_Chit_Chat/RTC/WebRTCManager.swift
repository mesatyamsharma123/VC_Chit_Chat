import Foundation
import WebRTC
import Combine

final class WebRTCManager: NSObject, ObservableObject {
    static let shared = WebRTCManager()
    
    // Published properties for your SwiftUI Views
    @Published var localVideoTrack: RTCVideoTrack?
    @Published var remoteVideoTrack: RTCVideoTrack?
    
    private let factory: RTCPeerConnectionFactory
    private(set) var peerConnection: RTCPeerConnection?
    private var videoCapturer: RTCCameraVideoCapturer?
    private var localVideoSource: RTCVideoSource?
    
    // Track who we are currently connected to
    private var remotePeerId: String?

    private override init() {
        // 1. Initialize WebRTC SSL and Factory
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        self.factory = RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
        
        super.init()
        setupLocalMedia()
    }

    // MARK: - Local Media Setup
    private func setupLocalMedia() {
        localVideoSource = factory.videoSource()
        videoCapturer = RTCCameraVideoCapturer(delegate: localVideoSource!)
        localVideoTrack = factory.videoTrack(with: localVideoSource!, trackId: "video0")
        
        // Start front camera
        guard let frontCamera = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == .front }),
              let format = RTCCameraVideoCapturer.supportedFormats(for: frontCamera).last,
              let fps = format.videoSupportedFrameRateRanges.first?.maxFrameRate else { return }
        
        videoCapturer?.startCapture(with: frontCamera, format: format, fps: Int(fps))
    }

    // MARK: - Connection Logic
    func prepareNewConnection(with peerId: String) {
        self.remotePeerId = peerId
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        self.peerConnection = factory.peerConnection(with: config, constraints: constraints, delegate: self)
        
        // Add our local video track to the connection
        if let localTrack = localVideoTrack {
            peerConnection?.add(localTrack, streamIds: ["stream0"])
        }
    }

    // MARK: - Signaling Handlers (Called by SignalingManager)
    
    func startCall(to peerId: String) {
        prepareNewConnection(with: peerId)
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveVideo": "true"], optionalConstraints: nil)
        peerConnection?.offer(for: constraints) { [weak self] sdp, _ in
            guard let sdp = sdp else { return }
            self?.peerConnection?.setLocalDescription(sdp) { _ in
                Task {
                    await SignalingManager.shared.sendSDP(sdp, to: peerId)
                }
            }
        }
    }

    func handleRemoteOffer(_ sdp: RTCSessionDescription, from peerId: String) {
        prepareNewConnection(with: peerId)
        
        peerConnection?.setRemoteDescription(sdp) { [weak self] _ in
            let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveVideo": "true"], optionalConstraints: nil)
            self?.peerConnection?.answer(for: constraints) { answerSdp, _ in
                guard let answerSdp = answerSdp else { return }
                self?.peerConnection?.setLocalDescription(answerSdp) { _ in
                    Task {
                        await SignalingManager.shared.sendSDP(answerSdp, to: peerId)
                    }
                }
            }
        }
    }

    func addIceCandidate(_ candidate: RTCIceCandidate) {
        peerConnection?.add(candidate)
    }
}

// MARK: - RTCPeerConnectionDelegate
extension WebRTCManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        guard let peerId = remotePeerId else { return }
        Task {
            await SignalingManager.shared.sendCandidate(candidate, to: peerId)
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        DispatchQueue.main.async {
            self.remoteVideoTrack = stream.videoTracks.first
        }
    }
    
    // Required Delegate Stubs
    func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCSignalingState) {}
    func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCIceConnectionState) {}
    func peerConnection(_ pc: RTCPeerConnection, didChange state: RTCIceGatheringState) {}
    func peerConnectionShouldNegotiate(_ pc: RTCPeerConnection) {}
    func peerConnection(_ pc: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnection(_ pc: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
    func peerConnection(_ pc: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
}
