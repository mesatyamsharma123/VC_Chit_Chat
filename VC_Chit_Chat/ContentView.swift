import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject var viewModel = CallViewModel()
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // 1. Remote Video (Background)
            if let remoteTrack = viewModel.remoteTrack {
                RTCVideoView(track: remoteTrack)
                    .edgesIgnoringSafeArea(.all)
            } else {
                VStack {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                    Text("Waiting for Video...")
                        .foregroundColor(.gray)
                }
            }
            
            VStack {
                HStack {
                    Text("My ID: \(SignalingManager.shared.myId)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .padding()
                    Spacer()
                    // 2. Local Video (Thumbnail)
                    RTCVideoView(track: viewModel.localTrack)
                        .frame(width: 120, height: 180)
                        .background(Color.black)
                        .cornerRadius(15)
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white, lineWidth: 1))
                        .padding()
                }
                
                Text(viewModel.status)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                
                Spacer()
                
                // 3. Control Buttons
                HStack(spacing: 40) {
                    if viewModel.status == "Disconnected" {
                        Button(action: { viewModel.connect() }) {
                            CircularButton(icon: "antenna.radiowaves.left.and.right", color: .blue, text: "Connect")
                        }
                    } else if viewModel.hasIncomingCall {
                        Button(action: { viewModel.answerCall() }) {
                            CircularButton(icon: "phone.fill", color: .green, text: "Answer")
                        }
                        Button(action: { viewModel.endCall() }) {
                            CircularButton(icon: "phone.down.fill", color: .red, text: "Decline")
                        }
                    } else if viewModel.status == "Server Connected" {
                        // In a real app, you'd type the other person's ID here
                        Button(action: { viewModel.startCall() }) {
                            CircularButton(icon: "phone.fill", color: .green, text: "Call Test")
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
