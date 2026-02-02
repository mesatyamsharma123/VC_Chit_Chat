//
//  RTCVideoView.swift
//  VC_Chit_Chat
//
//  Created by Satyam Sharma Chingari on 02/02/26.
//

import Foundation
import SwiftUI
import WebRTC

struct RTCVideoView: UIViewRepresentable {
    let track: RTCVideoTrack?

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView()
        view.videoContentMode = .scaleAspectFill
        return view
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        if let track = track {
            track.add(uiView)
        }
    }
}
