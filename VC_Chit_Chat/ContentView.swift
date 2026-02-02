import SwiftUI
import AVFoundation
import Combine

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject var viewModel = CallViewModel()
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Remote Video
            if let remoteTrack = viewModel.remoteTrack {
                RTCVideoView(track: remoteTrack)
                    .edgesIgnoringSafeArea(.all)
            } else {
                VStack {
                    Image(systemName: "video.slash.fill")
                        .foregroundColor(.gray)
                        .font(.largeTitle)
                    Text(viewModel.status)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top)
                }
            }
            
            VStack {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("MY ID")
                            .font(.caption2).foregroundColor(.gray)
                        Text(SignalingManager.shared.myId)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    .padding()
                    .background(Color.black.opacity(0.5).cornerRadius(10))
                    
                    Spacer()
                    
                    RTCVideoView(track: viewModel.localTrack)
                        .frame(width: 90, height: 130)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2)))
                }
                .padding()

                Spacer()
                
                // Call Input
                if viewModel.status == "Server Connected" || viewModel.status == "Disconnected" {
                    VStack(spacing: 15) {
                        Text("Enter Target ID (e.g. 323)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        TextField("ID Number", text: $viewModel.targetId)
                            .keyboardType(.numberPad) // Easier for just numbers
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 200)
                    }
                }

                Spacer()

                // Buttons
                HStack(spacing: 40) {
                    if !SignalingManager.shared.isConnected {
                        Button(action: { viewModel.connect() }) {
                            CircularButton(icon: "antenna.radiowaves.left.and.right", color: .blue, text: "Go Online")
                        }
                    } else if viewModel.hasIncomingCall {
                        Button(action: { viewModel.answerCall() }) {
                            CircularButton(icon: "phone.fill", color: .green, text: "Answer")
                        }
                        Button(action: { viewModel.endCall() }) {
                            CircularButton(icon: "phone.down.fill", color: .red, text: "Decline")
                        }
                    } else if viewModel.status == "Server Connected" {
                        Button(action: { viewModel.startCall() }) {
                            CircularButton(icon: "video.fill", color: .green, text: "Call")
                        }
                    } else {
                        Button(action: { viewModel.endCall() }) {
                            CircularButton(icon: "phone.down.fill", color: .red, text: "End")
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
}
// Updated Button Component for better touch targets
struct CircularButton: View {
    var icon: String
    var color: Color
    var text: String
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 65, height: 65)
                    .shadow(color: color.opacity(0.4), radius: 10, x: 0, y: 5)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
