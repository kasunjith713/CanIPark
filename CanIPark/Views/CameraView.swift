// CameraView.swift
// CanIPark
//
// Camera preview with capture button, guidance overlay, and photo library import.

import SwiftUI
import AVFoundation
import PhotosUI

struct CameraView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPermissionAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                CameraPreviewLayer()
                    .ignoresSafeArea()

                // Guidance overlay
                guidanceOverlay

                // Bottom controls
                VStack {
                    Spacer()
                    controlBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .alert("Camera Access Required", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("CanIPark needs camera access to scan parking signs. Please enable it in Settings.")
            }
            .task {
                if appState.cameraPermission == .notDetermined {
                    await appState.requestCameraPermission()
                }
                if appState.cameraPermission == .denied || appState.cameraPermission == .restricted {
                    showPermissionAlert = true
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let item = newValue else { return }
                Task {
                    await loadFromLibrary(item: item)
                }
            }
        }
    }

    // MARK: - Guidance Overlay

    private var guidanceOverlay: some View {
        VStack {
            // Sign frame guide
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                .frame(width: 280, height: 200)
                .overlay(alignment: .bottom) {
                    Text("Align parking sign within frame")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6), in: Capsule())
                        .offset(y: 32)
                }
                .padding(.top, 100)
                .accessibilityLabel("Sign alignment guide")

            Spacer()
        }
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: 40) {
            // Photo library picker
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Choose from photo library")

            // Capture button
            Button {
                capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 72, height: 72)
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 80, height: 80)
                }
            }
            .accessibilityLabel("Take photo")
            .accessibilityHint("Captures a photo of the parking sign")

            // Placeholder for symmetry
            Color.clear
                .frame(width: 56, height: 56)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Actions

    private func capturePhoto() {
        // In a real app, this would capture from the AVCaptureSession.
        // For now, create a placeholder image and begin analysis.
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300))
        let placeholder = renderer.image { context in
            UIColor.systemGray5.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        dismiss()
        appState.beginAnalysis(image: placeholder)
    }

    private func loadFromLibrary(item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await MainActor.run {
            dismiss()
            appState.beginAnalysis(image: image)
        }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

struct CameraPreviewLayer: UIViewRepresentable {

    func makeUIView(context: Context) -> CameraPreviewUIView {
        CameraPreviewUIView()
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

final class CameraPreviewUIView: UIView {

    private var captureSession: AVCaptureSession?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        setupCamera()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let previewLayer = layer.sublayers?.compactMap({ $0 as? AVCaptureVideoPreviewLayer }).first {
            previewLayer.frame = bounds
        }
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return }

        session.addInput(input)

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = bounds
        layer.addSublayer(previewLayer)

        captureSession = session

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    deinit {
        captureSession?.stopRunning()
    }
}

#Preview {
    CameraView()
        .environment(AppState())
}
