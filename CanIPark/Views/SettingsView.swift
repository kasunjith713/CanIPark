// SettingsView.swift
// CanIPark
//
// Jurisdiction picker, permissions, disclaimer, and about information.

import SwiftUI

struct SettingsView: View {

    @Environment(AppState.self) private var appState

    @State private var showDisclaimer = false

    var body: some View {
        @Bindable var state = appState

        NavigationStack {
            List {
                jurisdictionSection
                permissionsSection
                legalSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showDisclaimer) {
                disclaimerSheet
            }
        }
    }

    // MARK: - Jurisdiction

    private var jurisdictionSection: some View {
        Section {
            Picker("State / Territory", selection: Binding(
                get: { appState.selectedJurisdiction },
                set: { appState.selectedJurisdiction = $0 }
            )) {
                ForEach(AustralianJurisdiction.allCases) { jurisdiction in
                    Text(jurisdiction.displayName)
                        .tag(jurisdiction)
                }
            }
            .accessibilityLabel("Select your Australian state or territory")
            .accessibilityHint("Parking rules may vary between jurisdictions")
        } header: {
            Text("Jurisdiction")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("Parking rules can vary between states and territories. Select your location for the most accurate interpretation.")
        }
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        Section {
            // Camera
            HStack {
                Label("Camera", systemImage: "camera.fill")
                Spacer()
                permissionBadge(for: cameraStatusText, granted: appState.cameraPermission == .authorized)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Camera permission: \(cameraStatusText)")

            if appState.cameraPermission == .notDetermined {
                Button("Grant Camera Access") {
                    Task { await appState.requestCameraPermission() }
                }
                .accessibilityLabel("Grant camera access")
            }

            // Photo Library
            HStack {
                Label("Photo Library", systemImage: "photo.fill")
                Spacer()
                permissionBadge(for: photoStatusText, granted: appState.photoLibraryPermission == .authorized)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Photo library permission: \(photoStatusText)")

            if appState.photoLibraryPermission == .notDetermined {
                Button("Grant Photo Library Access") {
                    Task { await appState.requestPhotoLibraryPermission() }
                }
                .accessibilityLabel("Grant photo library access")
            }

            // Open settings link
            if appState.cameraPermission == .denied || appState.photoLibraryPermission == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open System Settings", systemImage: "gear")
                }
                .accessibilityLabel("Open system settings to change permissions")
            }
        } header: {
            Text("Permissions")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("Camera access is required to scan signs. Photo library access lets you analyse saved photos.")
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        Section {
            Button {
                showDisclaimer = true
            } label: {
                Label("Disclaimer", systemImage: "exclamationmark.shield.fill")
            }
            .accessibilityLabel("View legal disclaimer")

            Link(destination: URL(string: "https://www.australia.gov.au")!) {
                Label("Australian Road Rules", systemImage: "link")
            }
            .accessibilityLabel("Open Australian road rules website")
        } header: {
            Text("Legal")
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("App version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")

            HStack {
                Text("Build")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            HStack {
                Text("Jurisdiction Engine")
                Spacer()
                Text(appState.selectedJurisdiction.rawValue)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        } header: {
            Text("About")
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Disclaimer Sheet

    private var disclaimerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Important Disclaimer")
                        .font(.title2)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)

                    Group {
                        disclaimerParagraph(
                            title: "Not Legal Advice",
                            body: "CanIPark is a tool to help you understand Australian parking signs. It does not provide legal advice. The interpretation provided is a guide only and may not be accurate in all circumstances."
                        )

                        disclaimerParagraph(
                            title: "Always Read the Signs",
                            body: "You are responsible for reading and complying with all parking signs. Do not rely solely on this app. If in doubt, do not park."
                        )

                        disclaimerParagraph(
                            title: "Accuracy Limitations",
                            body: "OCR (optical character recognition) and sign detection are not perfect. Poor lighting, obscured signs, damaged signs, or unusual sign formats may lead to incorrect results."
                        )

                        disclaimerParagraph(
                            title: "Liability",
                            body: "The developers of CanIPark accept no liability for parking fines, towing, or any other consequences arising from the use of this app. Use at your own risk."
                        )

                        disclaimerParagraph(
                            title: "Public Holidays & School Zones",
                            body: "Public holiday and school zone detection may not cover all jurisdictions or dates. Always verify independently whether a public holiday or school zone applies."
                        )
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDisclaimer = false }
                }
            }
        }
    }

    private func disclaimerParagraph(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var cameraStatusText: String {
        switch appState.cameraPermission {
        case .authorized:     return "Granted"
        case .denied:         return "Denied"
        case .restricted:     return "Restricted"
        case .notDetermined:  return "Not Set"
        @unknown default:     return "Unknown"
        }
    }

    private var photoStatusText: String {
        switch appState.photoLibraryPermission {
        case .authorized, .limited: return "Granted"
        case .denied:               return "Denied"
        case .restricted:           return "Restricted"
        case .notDetermined:        return "Not Set"
        @unknown default:           return "Unknown"
        }
    }

    private func permissionBadge(for text: String, granted: Bool) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(granted ? Color.green.opacity(0.12) : Color.orange.opacity(0.12), in: Capsule())
            .foregroundStyle(granted ? .green : .orange)
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
