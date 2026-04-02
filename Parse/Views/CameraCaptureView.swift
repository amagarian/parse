import SwiftUI
import PhotosUI
import AVFoundation

struct CameraCaptureView: View {
    @Binding var capturedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var cameraPermissionDenied = false

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    HStack(spacing: 7) {
                        ParseMark(size: 14)
                        Text("parse")
                            .font(.system(size: 17, weight: .light, design: .serif))
                            .tracking(-0.5)
                            .foregroundColor(Color.theme.textPrimary)
                    }
                    Spacer()
                    Text("New Split")
                        .font(.system(size: 9, weight: .light))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundColor(Color.theme.textSecondary)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)

                // Step label
                Text("Step 1 of 3 — Scan Receipt")
                    .font(.system(size: 8, weight: .light))
                    .tracking(2.5)
                    .textCase(.uppercase)
                    .foregroundColor(Color.theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 16)

                Spacer()

                // Viewfinder — vertically centered between header and buttons
                viewfinderArea
                    .padding(.horizontal, 22)

                Spacer()

                // Buttons
                VStack(spacing: 0) {
                    Button { requestCameraAccess() } label: {
                        Text("Take Photo")
                            .font(.system(size: 11, weight: .light, design: .monospaced))
                            .tracking(2.5)
                            .textCase(.uppercase)
                            .foregroundColor(Color(hex: 0x0B0907))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: 0xEDE3D4))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text("Upload from Camera Roll")
                            .font(.system(size: 10, weight: .light, design: .monospaced))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundColor(Color.theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.theme.rule, lineWidth: 1)
                            )
                    }
                    .padding(.top, 10)

                    Button { dismiss() } label: {
                        Text("Cancel")
                            .font(.system(size: 10, weight: .light))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundColor(Color.theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ImagePickerView(image: $capturedImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        .alert("Camera Access Required", isPresented: $cameraPermissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable camera access in Settings to scan receipts.")
        }
        .onChange(of: capturedImage) { _, newImage in
            if newImage != nil { dismiss() }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    capturedImage = image
                }
            }
        }
    }

    // MARK: — Viewfinder

    private var viewfinderArea: some View {
        ZStack {
            // Corner brackets only — open frame, no card fill
            GeometryReader { geo in
                let m: CGFloat = 24
                let len: CGFloat = 22
                let t: CGFloat = 1.2

                Group {
                    cornerBracket(x: m, y: m, len: len, t: t, flipH: false, flipV: false)
                    cornerBracket(x: geo.size.width - m, y: m, len: len, t: t, flipH: true, flipV: false)
                    cornerBracket(x: m, y: geo.size.height - m, len: len, t: t, flipH: false, flipV: true)
                    cornerBracket(x: geo.size.width - m, y: geo.size.height - m, len: len, t: t, flipH: true, flipV: true)
                }
            }

            // Animated scan line
            ScanLine()

            // Label — centered inside the frame
            Text("Tap below to scan")
                .font(.system(size: 8, weight: .light))
                .tracking(2.5)
                .textCase(.uppercase)
                .foregroundColor(Color.theme.textSecondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(3/4, contentMode: .fit)
    }

    private func cornerBracket(x: CGFloat, y: CGFloat, len: CGFloat, t: CGFloat, flipH: Bool, flipV: Bool) -> some View {
        let hSign: CGFloat = flipH ? -1 : 1
        let vSign: CGFloat = flipV ? -1 : 1
        return Path { p in
            p.move(to: CGPoint(x: x + hSign * len, y: y))
            p.addLine(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x, y: y + vSign * len))
        }
        .stroke(Color.theme.accentSecondary, style: StrokeStyle(lineWidth: t, lineCap: .square))
    }

    // MARK: — Camera Permission

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showCamera = true } else { cameraPermissionDenied = true }
                }
            }
        default:
            cameraPermissionDenied = true
        }
    }
}

// MARK: — Scan Line Animation

private struct ScanLine: View {
    /// Must match the bracket margin in viewfinderArea so the line stays inside the frame.
    private let inset: CGFloat = 24
    @State private var atBottom = false

    var body: some View {
        GeometryReader { geo in
            let travel = geo.size.height - inset * 2
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.theme.accentSecondary.opacity(0.8), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .offset(y: inset + (atBottom ? travel : 0))
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        atBottom = true
                    }
                }
        }
    }
}

// MARK: — UIImagePickerController Bridge

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        init(_ parent: ImagePickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.image = image }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
