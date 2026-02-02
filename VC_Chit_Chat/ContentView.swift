import SwiftUI
import AVFoundation
import Combine

struct ContentView: View {
    @StateObject var viewModel = CallViewModel()
    @State private var showIdCopiedAlert = false // For UI feedback
    
    var body: some View {
        ZStack {
            // Background Layer
            Color.black.edgesIgnoringSafeArea(.all)
            
            // 1. Remote Video (Background)
            Group {
                if let remoteTrack = viewModel.remoteTrack {
                    RTCVideoView(track: remoteTrack)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text(viewModel.status == "Connected" ? "Waiting for video..." : "Ready to Connect")
                            .foregroundColor(.gray)
                            .font(.callout)
                    }
                }
            }
            
            // 2. Overlay Layer (UI Elements)
            VStack {
                // Top Bar: My ID and Local Preview
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My ID")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack {
                            Text(SignalingManager.shared.myId)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.cyan)
                            
                            // Copy Button for convenience
                            Button(action: {
                                UIPasteboard.general.string = SignalingManager.shared.myId
                                showIdCopiedAlert = true
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.4)))
                    .padding(.leading)
                    
                    Spacer()
                    
                    // Local Video Thumbnail (PIP)
                    RTCVideoView(track: viewModel.localTrack)
                        .frame(width: 100, height: 150)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3), lineWidth: 1))
                        .shadow(radius: 10)
                        .padding(.trailing)
                }
                .padding(.top, 10)
                
                Spacer()
                
                // Interaction Layer: ID Entry
                if viewModel.status == "Server Connected" || viewModel.status == "Disconnected" {
                    VStack(spacing: 12) {
                        Text("Who do you want to call?")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        TextField("Enter Target ID", text: $viewModel.targetId)
                            .padding()
                            .background(BlurView(style: .systemMaterialDark))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .accentColor(.blue)
                            .multilineTextAlignment(.center)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .frame(maxWidth: 220)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 30)
                }
                
                // Status Indicator
                Text(viewModel.status.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .kerning(1.5)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(viewModel.status == "Connected" ? Color.green.opacity(0.6) : Color.blue.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(.bottom, 20)
                
                // 3. Control Buttons Logic
                HStack(spacing: 45) {
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
                            CircularButton(icon: "video.fill", color: .green, text: "Start Call")
                        }
                    } else {
                        // End call button for active sessions
                        Button(action: { viewModel.endCall() }) {
                            CircularButton(icon: "phone.down.fill", color: .red, text: "Hang Up")
                        }
                    }
                }
                .padding(.bottom, 50)
                .animation(.spring(), value: viewModel.status)
            }
        }
        .onAppear {
            requestAccess()
        }
        .alert("ID Copied", isPresented: $showIdCopiedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Share your ID with a friend to start a chat.")
        }
    }
    
    func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
}

// Helper for blurred background in ID input
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
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
