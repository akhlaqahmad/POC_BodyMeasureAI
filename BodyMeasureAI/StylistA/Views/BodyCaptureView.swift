//
//  BodyCaptureView.swift
//  BodyMeasureAI
//
//  Full-screen camera feed with skeleton overlay, distance/pose instructions, capture button.
//

import SwiftUI
import AVFoundation
import Vision

struct BodyCaptureView: View {
    @ObservedObject var viewModel: BodyCaptureViewModel
    var hideTopInstruction: Bool = false
    var onCaptured: (BodyScanResult) -> Void
    
    @State private var isCameraSwitching: Bool = false

    var body: some View {
        ZStack {
            CameraPreviewView(session: viewModel.session)
                .ignoresSafeArea()
                .blur(radius: isCameraSwitching ? 20 : 0)
                .opacity(isCameraSwitching ? 0.5 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isCameraSwitching)
                
            DistanceGuideOverlay(
                isPositioned: viewModel.canCapture
            )
            .ignoresSafeArea()

            SkeletonOverlayView(observation: viewModel.currentObservation)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                
            // Large Countdown Overlay for Single User Scenario
            if viewModel.isCountingDown {
                Text("\(viewModel.countdown)")
                    .font(.system(size: 140, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.countdown)
                    .zIndex(500)
            }

            // Top gradient + instruction
            VStack(alignment: .leading, spacing: SSpacing.xs) {
                if !hideTopInstruction {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BODY SCAN")
                                .font(SFont.label(11))
                                .tracking(3)
                                .foregroundStyle(.white.opacity(0.6))
                            Text(topInstructionText)
                                .font(SFont.body(14))
                                .foregroundStyle(.white)
                                .animation(.easeInOut(duration: 0.3),
                                           value: topInstructionText)
                        }
                        Spacer()
                        if viewModel.currentObservation != nil {
                            Text("\(Int(viewModel.currentConfidence * 100))%")
                                .font(SFont.mono(12))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.white.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(SSpacing.md)
                    .padding(.top, 110) // extra space to clear the navigation back button
                    .background(
                        LinearGradient(
                            colors: [.black.opacity(0.6), .clear],
                            startPoint: .top,
                            endPoint: .bottom))
                    
                    // Tips when nothing is detected yet.
                    if viewModel.currentConfidence == 0 && !viewModel.cameraDenied {
                        VStack(alignment: .leading, spacing: 4) {
                            tipRow("Stand 2–2.5 metres from camera")
                            tipRow("Full body must be visible")
                            tipRow("Good lighting — face a light source")
                            tipRow("Plain background works best")
                        }
                        .padding(SSpacing.sm)
                        .background(.black.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: SRadius.sm))
                        .padding(.horizontal, SSpacing.lg)
                    }
                }
                
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false) // Let touches pass through the gradient view to buttons behind it

            // Bottom capture area
            VStack {
                Spacer()

                // Not in frame warning
                if let msg = viewModel.bodyNotInFrameMessage {
                    Text(msg)
                        .font(SFont.body(13))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SSpacing.md)
                        .padding(.vertical, SSpacing.sm)
                        .background(Color("sError").opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: SRadius.sm))
                        .padding(.horizontal, SSpacing.lg)
                        .transition(
                            .move(edge: .bottom).combined(with: .opacity))
                }

                // Glass bottom card
                HStack(alignment: .center, spacing: SSpacing.lg) {

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(viewModel.canCapture
                                        ? Color("sSuccess") : Color("sTertiary"))
                                .frame(width: 6, height: 6)
                            Text(viewModel.canCapture ? "Ready" : "Scanning")
                                .font(SFont.label(12))
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        // Confidence bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.15))
                                    .frame(height: 3)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(viewModel.canCapture
                                          ? Color("sSuccess")
                                          : Color.white.opacity(0.7))
                                    .frame(
                                        width: geo.size.width
                                            * CGFloat(min(viewModel.currentConfidence, 1.0)),
                                        height: 3)
                                    .animation(.easeInOut(duration: 0.3),
                                               value: viewModel.currentConfidence)
                            }
                        }
                        .frame(height: 3)
                        .frame(width: 120)
                    }

                    Spacer()

                    // Capture button — minimal ring
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.capture()
                            if let result = viewModel.capturedResult {
                                onCaptured(result)
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 72, height: 72)
                            
                            if viewModel.isCountingDown {
                                // Stop button style
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color("sError"))
                                    .frame(width: 32, height: 32)
                            } else {
                                Circle()
                                    .fill(viewModel.canCapture
                                        ? Color.white
                                        : Color.white.opacity(0.2))
                                    .frame(width: 56, height: 56)
                                    .scaleEffect(viewModel.canCapture ? 1.0 : 0.85)
                            }
                        }
                        .animation(
                            .spring(response: 0.4,
                                    dampingFraction: 0.6),
                            value: viewModel.canCapture)
                        .animation(.easeInOut, value: viewModel.isCountingDown)
                    }
                    .disabled(!viewModel.canCapture && !viewModel.isCountingDown)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, SSpacing.lg)
                .padding(.vertical, SSpacing.md)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: SRadius.lg))
                .padding(.horizontal, SSpacing.md)
                .padding(.bottom, SSpacing.xxl)
            }
            .allowsHitTesting(true) // Ensure this part still receives touches
            
            // Floating Camera Switch & Timer Buttons
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: SSpacing.md) {
                        Button(action: {
                            toggleCamera()
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isCountingDown)
                        .opacity(viewModel.isCountingDown ? 0.5 : 1.0)
                        
                        Button(action: {
                            cycleTimer()
                        }) {
                            ZStack {
                                Image(systemName: "timer")
                                    .font(.system(size: 20))
                                    .foregroundStyle(viewModel.selectedTimer > 0 ? Color("sSuccess") : .white)
                                
                                if viewModel.selectedTimer > 0 {
                                    Text("\(viewModel.selectedTimer)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color("sSuccess"))
                                        .offset(x: 10, y: 10)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isCountingDown)
                        .opacity(viewModel.isCountingDown ? 0.5 : 1.0)
                    }
                    .zIndex(10) // Ensure it stays on top of other elements
                }
                .padding(.horizontal, SSpacing.md)
                .padding(.top, 60)
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(true) // Ensure button can be tapped
            .zIndex(1000)

            // Camera denied
            if viewModel.cameraDenied {
                ZStack {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack(spacing: SSpacing.md) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color("sTertiary"))
                        Text("Camera access required")
                            .font(SFont.heading(18))
                            .foregroundStyle(.white)
                        Text("Please enable camera in Settings.")
                            .font(SFont.body(14))
                            .foregroundStyle(.white.opacity(0.6))
                        if let url = URL(
                            string: UIApplication.openSettingsURLString) {
                            Link("Open Settings", destination: url)
                                .font(SFont.label(14))
                                .foregroundStyle(.white)
                                .padding(.horizontal, SSpacing.lg)
                                .padding(.vertical, SSpacing.sm)
                                .background(.white.opacity(0.15))
                                .clipShape(RoundedRectangle(
                                    cornerRadius: SRadius.sm))
                        }
                    }
                    .padding(SSpacing.xl)
                }
            }
        }
        .onAppear { viewModel.requestCameraAndConfigure() }
        .onDisappear { viewModel.stopSession() }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                guard !viewModel.isCountingDown else { return }
                #if DEBUG
                print("👆 Double tap detected on BodyCaptureView")
                #endif
                toggleCamera()
            }
        )
    }
    
    private func toggleCamera() {
        guard !isCameraSwitching else { return }
        #if DEBUG
        print("🎛️ BodyCaptureView.toggleCamera called")
        #endif
        
        // Haptic feedback for the gesture/tap
        let impactMed = UIImpactFeedbackGenerator(style: .medium)
        impactMed.impactOccurred()
        
        isCameraSwitching = true
        
        // Switch the camera model-side
        viewModel.toggleCamera()
        
        // Give it a brief moment before removing the blur, to let the feed restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isCameraSwitching = false
        }
    }
    
    private func cycleTimer() {
        let impactLight = UIImpactFeedbackGenerator(style: .light)
        impactLight.impactOccurred()
        
        switch viewModel.selectedTimer {
        case 0: viewModel.selectedTimer = 3
        case 3: viewModel.selectedTimer = 5
        case 5: viewModel.selectedTimer = 10
        case 10: viewModel.selectedTimer = 0
        default: viewModel.selectedTimer = 0
        }
    }

    private var topInstructionText: String {
        if viewModel.canCapture {
            return "Tap the button to capture"
        } else if let msg = viewModel.bodyNotInFrameMessage {
            return msg
        } else if viewModel.currentConfidence >= 0.4 {
            return "Good — hold this position"
        } else if viewModel.currentConfidence > 0 {
            return "Step back — full body in frame"
        } else {
            return "Stand in frame · Arms slightly out"
        }
    }

    private func tipRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.white.opacity(0.4))
                .frame(width: 4, height: 4)
            Text(text)
                .font(SFont.body(12))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Distance guide overlay (floor footprint + body boundary)

struct DistanceGuideOverlay: View {
    /// true when body is detected AND confidence > 0.6
    let isPositioned: Bool

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let strokeColor: Color = isPositioned
                ? Color.green.opacity(0.55)
                : Color.white.opacity(0.35)

            // Canvas draws the ellipse and dotted guide lines
            Canvas { context, canvasSize in

                // -- Floor footprint ellipse --
                // Positioned at bottom 15% of screen, centered horizontally
                let ellipseW = canvasSize.width * 0.55
                let ellipseH = canvasSize.height * 0.07
                let ellipseX = (canvasSize.width - ellipseW) / 2
                let ellipseY = canvasSize.height * 0.83
                let ellipseRect = CGRect(x: ellipseX, y: ellipseY,
                                         width: ellipseW, height: ellipseH)
                let ellipsePath = Path(ellipseIn: ellipseRect)
                context.stroke(ellipsePath,
                               with: .color(strokeColor),
                               lineWidth: 2)

                // -- Left vertical dotted guide line --
                // Runs from bottom of ellipse up to 10% from top
                let leftX  = ellipseX + ellipseW * 0.15
                let rightX = ellipseX + ellipseW * 0.85
                let topY   = canvasSize.height * 0.10
                let bottomY = ellipseY + ellipseH / 2

                var leftLine = Path()
                leftLine.move(to: CGPoint(x: leftX, y: bottomY))
                leftLine.addLine(to: CGPoint(x: leftX, y: topY))
                context.stroke(leftLine,
                               with: .color(strokeColor),
                               style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))

                // -- Right vertical dotted guide line --
                var rightLine = Path()
                rightLine.move(to: CGPoint(x: rightX, y: bottomY))
                rightLine.addLine(to: CGPoint(x: rightX, y: topY))
                context.stroke(rightLine,
                               with: .color(strokeColor),
                               style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
            }
            .ignoresSafeArea()

            // -- "Stand here" text label inside the ellipse --
            VStack {
                Spacer()
                Text("Stand here")
                    .font(.caption2)
                    .foregroundStyle(
                        isPositioned
                            ? Color.green.opacity(0.9)
                            : Color.white.opacity(0.7)
                    )
                    .padding(.bottom, size.height * 0.13)
            }
            .frame(maxWidth: .infinity)
        }
        .allowsHitTesting(false) // overlay never blocks touches
    }
}

// MARK: - Camera preview (AVCaptureVideoPreviewLayer)

/// Host view that keeps the preview layer frame in sync with bounds (fixes black screen when bounds are set after layout).
 final class CameraPreviewHostView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewHostView {
        let view = CameraPreviewHostView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewHostView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        uiView.previewLayer.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {}
}

// MARK: - Skeleton overlay (lines + dots from keypoints)

struct SkeletonOverlayView: View {
    let observation: VNHumanBodyPoseObservation?
    /// Size of the overlay in points (same as camera view).
    @State private var size: CGSize = .zero

    private static let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.nose, .neck),
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow),
        (.rightShoulder, .rightElbow),
        (.leftElbow, .leftWrist),
        (.rightElbow, .rightWrist),
        (.neck, .leftShoulder),
        (.neck, .rightShoulder),
        (.root, .leftHip),
        (.root, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee),
        (.rightHip, .rightKnee),
        (.leftKnee, .leftAnkle),
        (.rightKnee, .rightAnkle),
        (.neck, .root)
    ]

    var body: some View {
        GeometryReader { geo in
            Canvas { context, canvasSize in
                guard let obs = observation else { return }
                let points = jointPointsInView(obs, viewSize: canvasSize)

                // Only draw skeleton when both left and right sides have enough reliable joints.
                let leftSide: [VNHumanBodyPoseObservation.JointName] = [
                    .leftShoulder, .leftHip, .leftKnee, .leftAnkle
                ]
                let rightSide: [VNHumanBodyPoseObservation.JointName] = [
                    .rightShoulder, .rightHip, .rightKnee, .rightAnkle
                ]
                let leftCount = leftSide.filter { points[$0] != nil }.count
                let rightCount = rightSide.filter { points[$0] != nil }.count

                guard leftCount >= 3, rightCount >= 3 else {
                    return  // avoid drawing a very wrong / one-sided skeleton
                }

                for (a, b) in Self.connections {
                    guard let pa = points[a], let pb = points[b] else { continue }
                    var path = Path()
                    path.move(to: pa)
                    path.addLine(to: pb)
                    context.stroke(path, with: .color(.white), lineWidth: 2)
                }
                for (_, p) in points {
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(.green))
                }
            }
            .onChange(of: geo.size) { _, newValue in size = newValue }
            .onAppear { size = geo.size }
        }
    }

    private func jointPointsInView(
        _ observation: VNHumanBodyPoseObservation,
        viewSize: CGSize
    ) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        var result: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for joint in observation.availableJointNames {
            guard let pt = try? observation.recognizedPoint(joint),
                  pt.confidence > 0.2 else { continue }
            // Vision: (0,0) = bottom-left, Y up. SwiftUI: (0,0) = top-left, Y down.
            let x = CGFloat(pt.location.x) * viewSize.width
            let y = (1.0 - CGFloat(pt.location.y)) * viewSize.height
            result[joint] = CGPoint(x: x, y: y)
        }
        return result
    }
}

