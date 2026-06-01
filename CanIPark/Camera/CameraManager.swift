// CameraManager.swift
// CanIPark
//
// Manages AVCaptureSession lifecycle, photo capture, and camera controls
// (torch, flash, zoom, focus). Provides a live frame delegate for
// real-time preview analysis.

import AVFoundation
import UIKit
import Combine

// MARK: - Camera Error

enum CameraError: LocalizedError {
    case unauthorised
    case deviceUnavailable
    case inputFailed
    case outputFailed
    case captureFailed(underlying: Error)
    case sessionNotRunning
    case torchUnavailable

    var errorDescription: String? {
        switch self {
        case .unauthorised:
            return "Camera access is not authorised. Enable it in Settings."
        case .deviceUnavailable:
            return "No suitable camera device was found."
        case .inputFailed:
            return "Failed to configure the camera input."
        case .outputFailed:
            return "Failed to configure the camera output."
        case .captureFailed(let underlying):
            return "Photo capture failed: \(underlying.localizedDescription)"
        case .sessionNotRunning:
            return "The camera session is not running."
        case .torchUnavailable:
            return "Torch (flashlight) is not available on this device."
        }
    }
}

// MARK: - Camera State

enum CameraState: Sendable {
    case idle
    case starting
    case running
    case stopped
    case failed(String)
}

// MARK: - Live Frame Delegate

protocol LiveFrameDelegate: AnyObject {
    /// Called on a background queue for each video frame.
    func cameraManager(_ manager: CameraManager, didOutput pixelBuffer: CVPixelBuffer, timestamp: CMTime)
}

// MARK: - Camera Manager

final class CameraManager: NSObject, ObservableObject, @unchecked Sendable {

    // MARK: Published State

    @Published private(set) var state: CameraState = .idle
    @Published private(set) var currentZoomFactor: CGFloat = 1.0
    @Published private(set) var isTorchOn: Bool = false
    @Published private(set) var flashMode: AVCaptureDevice.FlashMode = .auto

    // MARK: Session

    let captureSession = AVCaptureSession()

    // MARK: Delegates

    weak var liveFrameDelegate: LiveFrameDelegate?

    // MARK: Configuration

    struct Configuration {
        var sessionPreset: AVCaptureSession.Preset = .photo
        var preferredPosition: AVCaptureDevice.Position = .back
        var enableLiveFrames: Bool = true
        /// Throttle live frames to this interval (seconds).
        var liveFrameInterval: TimeInterval = 0.1

        static let `default` = Configuration()
    }

    private let configuration: Configuration

    // MARK: Private Properties

    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.canipark.camera.session", qos: .userInitiated)
    private let videoOutputQueue = DispatchQueue(label: "com.canipark.camera.videoOutput", qos: .userInitiated)

    /// Pending photo capture continuation.
    private var photoContinuation: CheckedContinuation<UIImage, Error>?

    /// Throttle live frame callbacks.
    private var lastFrameTime: CFAbsoluteTime = 0

    // MARK: - Initialisation

    init(configuration: Configuration = .default) {
        self.configuration = configuration
        super.init()
    }

    deinit {
        stopSession()
    }

    // MARK: - Authorisation

    /// Request camera authorisation.
    func requestAuthorisation() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Session Lifecycle

    /// Configure and start the capture session.
    func startSession() async throws {
        guard await requestAuthorisation() else {
            updateState(.failed("Camera access denied"))
            throw CameraError.unauthorised
        }

        updateState(.starting)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CameraError.deviceUnavailable)
                    return
                }
                do {
                    try self.configureSession()
                    self.captureSession.startRunning()
                    self.updateState(.running)
                    continuation.resume()
                } catch {
                    self.updateState(.failed(error.localizedDescription))
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Stop the capture session.
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            self.updateState(.stopped)
        }
    }

    // MARK: - Session Configuration

    private func configureSession() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.sessionPreset = configuration.sessionPreset

        // Video input.
        guard let device = bestDevice(for: configuration.preferredPosition) else {
            throw CameraError.deviceUnavailable
        }
        videoDevice = device

        let input = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(input) else {
            throw CameraError.inputFailed
        }
        captureSession.addInput(input)
        videoInput = input

        // Photo output.
        guard captureSession.canAddOutput(photoOutput) else {
            throw CameraError.outputFailed
        }
        captureSession.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = true
        photoOutput.maxPhotoQualityPrioritization = .quality

        // Video output for live frames.
        if configuration.enableLiveFrames {
            videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
        }
    }

    private func bestDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // Prefer wide-angle camera.
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTripleCamera],
            mediaType: .video,
            position: position
        )
        return discoverySession.devices.first
    }

    // MARK: - Photo Capture

    /// Capture a full-resolution photo and return it as a UIImage.
    func capturePhoto() async throws -> UIImage {
        guard captureSession.isRunning else {
            throw CameraError.sessionNotRunning
        }

        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CameraError.sessionNotRunning)
                    return
                }

                self.photoContinuation = continuation

                let settings = AVCapturePhotoSettings()
                settings.flashMode = self.flashMode

                if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    settings.photoQualityPrioritization = .quality
                }

                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    // MARK: - Torch Control

    /// Toggle the torch (flashlight) on or off.
    func setTorch(enabled: Bool) throws {
        guard let device = videoDevice, device.hasTorch else {
            throw CameraError.torchUnavailable
        }

        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        if enabled {
            try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
        } else {
            device.torchMode = .off
        }

        DispatchQueue.main.async { [weak self] in
            self?.isTorchOn = enabled
        }
    }

    /// Toggle torch state.
    func toggleTorch() throws {
        try setTorch(enabled: !isTorchOn)
    }

    // MARK: - Flash Control

    /// Set the flash mode for photo capture.
    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
        DispatchQueue.main.async { [weak self] in
            self?.flashMode = mode
        }
    }

    /// Cycle through flash modes: auto -> on -> off -> auto.
    func cycleFlashMode() {
        let next: AVCaptureDevice.FlashMode
        switch flashMode {
        case .auto: next = .on
        case .on:   next = .off
        case .off:  next = .auto
        @unknown default: next = .auto
        }
        setFlashMode(next)
    }

    // MARK: - Zoom Control

    /// Set the zoom factor with a smooth ramp.
    func setZoom(_ factor: CGFloat, animated: Bool = true) {
        guard let device = videoDevice else { return }
        let clamped = min(max(factor, 1.0), device.activeFormat.videoMaxZoomFactor)

        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try device.lockForConfiguration()
                if animated {
                    device.ramp(toVideoZoomFactor: clamped, withRate: 4.0)
                } else {
                    device.videoZoomFactor = clamped
                }
                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.currentZoomFactor = clamped
                }
            } catch {
                // Zoom failure is non-critical.
            }
        }
    }

    /// Maximum zoom factor for the current device.
    var maxZoomFactor: CGFloat {
        guard let device = videoDevice else { return 1.0 }
        // Limit to a practical maximum for sign reading.
        return min(device.activeFormat.videoMaxZoomFactor, 10.0)
    }

    // MARK: - Focus Control

    /// Focus at a specific point in the preview (0-1 normalised coordinates).
    func focus(at point: CGPoint) {
        guard let device = videoDevice else { return }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()

                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }

                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }

                device.unlockForConfiguration()
            } catch {
                // Focus failure is non-critical.
            }
        }
    }

    /// Lock focus at the current distance.
    func lockFocus() {
        guard let device = videoDevice else { return }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.locked) {
                    device.focusMode = .locked
                }
                device.unlockForConfiguration()
            } catch {
                // Non-critical.
            }
        }
    }

    /// Unlock focus and return to continuous auto-focus.
    func unlockFocus() {
        guard let device = videoDevice else { return }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch {
                // Non-critical.
            }
        }
    }

    // MARK: - State Updates

    private func updateState(_ newState: CameraState) {
        DispatchQueue.main.async { [weak self] in
            self?.state = newState
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            photoContinuation?.resume(throwing: CameraError.captureFailed(underlying: error))
            photoContinuation = nil
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoContinuation?.resume(throwing: CameraError.captureFailed(
                underlying: NSError(domain: "CameraManager", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Failed to create image from photo data."])
            ))
            photoContinuation = nil
            return
        }

        photoContinuation?.resume(returning: image)
        photoContinuation = nil
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Throttle frame delivery.
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastFrameTime >= configuration.liveFrameInterval else { return }
        lastFrameTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        liveFrameDelegate?.cameraManager(self, didOutput: pixelBuffer, timestamp: timestamp)
    }
}
