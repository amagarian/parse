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

                // Viewfinder
                viewfinderArea
                    .padding(.horizontal, 22)

                // Tip
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.theme.textSecondary)
                        .frame(width: 4, height: 4)
                        .padding(.top, 5)
                    Text("Ensure the full receipt is visible within the frame. Works best in good lighting.")
                        .font(.system(size: 9, weight: .light))
                        .tracking(0.5)
                        .foregroundColor(Color.theme.textSecondary)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 20)

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
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.theme.rule, lineWidth: 1)
                )

            // Ambient glow
            RadialGradient(
                colors: [Color.theme.accent.opacity(0.05), .clear],
                center: .center, startRadius: 0, endRadius: 120
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Corner brackets
            GeometryReader { geo in
                let m: CGFloat = 20
                let len: CGFloat = 18
                let t: CGFloat = 1

                Group {
                    // TL
                    cornerBracket(x: m, y: m, len: len, t: t, flipH: false, flipV: false)
                    // TR
                    cornerBracket(x: geo.size.width - m, y: m, len: len, t: t, flipH: true, flipV: false)
                    // BL
                    cornerBracket(x: m, y: geo.size.height - m, len: len, t: t, flipH: false, flipV: true)
                    // BR
                    cornerBracket(x: geo.size.width - m, y: geo.size.height - m, len: len, t: t, flipH: true, flipV: true)
                }
            }

            // Animated scan line
            ScanLine()

            VStack(spacing: 10) {
                Text("🧾")
                    .font(.system(size: 28))
                    .opacity(0.45)
                Text("Point at receipt")
                    .font(.system(size: 8, weight: .light))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(Color.theme.textSecondary)
            }
        }
        .frame(height: 280)
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
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.theme.accentSecondary, .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .opacity(0.7)
                .offset(y: offset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        offset = h - 40
                    }
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
