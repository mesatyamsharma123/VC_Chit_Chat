import SwiftUI
import AVFoundation
import Combine

struct ContentView: View {
    @StateObject var viewModel = CallViewModel()
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // 1. Remote Video (Full Screen Background)
            if let remoteTrack = viewModel.remoteTrack {
                RTCVideoView(track: remoteTrack)
                    .edgesIgnoringSafeArea(.all)
            } else {
                VStack {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                    Text("Waiting for Connection...")
                        .foregroundColor(.gray)
                }
            }
            
            VStack {
                // Top Header: My ID and Local Preview
                HStack {
                    VStack(alignment: .leading) {
                        Text("My ID")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        Text(SignalingManager.shared.myId)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Local Video Thumbnail
                    RTCVideoView(track: viewModel.localTrack)
                        .frame(width: 100, height: 140)
                        .background(Color.black)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3), lineWidth: 1))
                        .padding()
                }
                
                // Connection Input (Only show when not in a call)
                if viewModel.status == "Server Connected" || viewModel.status == "Disconnected" {
                    VStack(spacing: 15) {
                        TextField("Enter Friend's ID", text: $viewModel.targetId)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .accentColor(.blue)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .frame(maxWidth: 250)
                    }
                    .padding()
                }

                // Status Indicator
                Text(viewModel.status)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.blue.opacity(0.3)))
                
                Spacer()
                
                // 3. Control Buttons Logic
                HStack(spacing: 40) {
                    if !SignalingManager.shared.isConnected {
                        Button(action: { viewModel.connect() }) {
                            CircularButton(icon: "antenna.radiowaves.left.and.right", color: .blue, text: "Go Online")
                        }
                    } else if viewModel.hasIncomingCall {
                        // Answer/Decline View
                        Button(action: { viewModel.answerCall() }) {
                            CircularButton(icon: "phone.fill", color: .green, text: "Answer")
                        }
                        Button(action: { viewModel.endCall() }) {
                            CircularButton(icon: "phone.down.fill", color: .red, text: "Decline")
                        }
                    } else if viewModel.status == "Server Connected" {
                        // Ready to call
                        Button(action: { viewModel.startCall() }) {
                            CircularButton(icon: "video.fill", color: .green, text: "Call")
                        }
                    } else {
                        // Active Call - Show End Button
                        Button(action: { viewModel.endCall() }) {
                            CircularButton(icon: "phone.down.fill", color: .red, text: "End")
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            requestAccess()
        }
    }
    
    func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
}
struct CircularButton: View {
    var icon: String
    var color: Color
    var text: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(text)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}

