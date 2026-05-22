import Foundation

#if canImport(FamilyControls) && canImport(ManagedSettings)
import FamilyControls
import ManagedSettings
import Combine

/// Manages FamilyControls and ManagedSettings operations for app authorization and restrictions.
/// 
/// - Note: Usage of FamilyControls requires the `com.apple.developer.family-controls` entitlement.
/// - Note: Restriction APIs require user authorization and are only available on supported platforms.
/// - Note: UI presentation for selecting applications must be handled in SwiftUI using `FamilyActivityPicker`.
@MainActor
final class FamilyControlsManager: ObservableObject {
    
    
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var selectedApplications: Set<ApplicationToken> = []
    @Published var isRestrictionsApplied: Bool = false
    @Published var lastError: String? = nil
    
    private let authorizationCenter = AuthorizationCenter.shared
    private let store = ManagedSettingsStore()
    
    
    private let defaults =
    UserDefaults(suiteName: "group.blocking")
    
    var isPickerAvailable: Bool {
        
        if #available(iOS 16.0, *) {
            return authorizationStatus == .approved ||
                   authorizationStatus == .approvedWithDataAccess
        }
        
        return false
    }
    
    /// Requests authorization for managing family controls.
//    func requestAuthorization() async {
//        do {
//            try await authorizationCenter.requestAuthorization(for: .individual)
//            // After requesting, read the current authorization status and map it
//            let current = authorizationCenter.authorizationStatus
//            authorizationStatus = Self.mapAuthorizationStatus(current)
//        } catch {
//            lastError = "Authorization request failed: \(error.localizedDescription)"
//            authorizationStatus = .notDetermined
//        }
//    }
    func requestAuthorization() async {

        do {

            try await authorizationCenter.requestAuthorization(
                for: .individual
            )

            authorizationStatus =
                Self.mapAuthorizationStatus(
                    authorizationCenter.authorizationStatus
                )

            print("Authorization:",
                  authorizationStatus)

        } catch {

            print(error)
        }
    }
    func restoreRestrictions() {

        guard let data =
            defaults?.data(forKey: "savedTokens")
        else {
            return
        }

        do {

            let tokens =
            try JSONDecoder().decode(
                Set<ApplicationToken>.self,
                from: data
            )

            selectedApplications = tokens

            store.shield.applications =
            tokens

            isRestrictionsApplied = true

        } catch {

            print("Failed to restore restrictions:", error)
        }
    }

    private static func mapAuthorizationStatus(_ status: FamilyControls.AuthorizationStatus) -> AuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .approved:
            return .approved
        case .denied:
            return .denied
        case .approvedWithDataAccess:
            return .approvedWithDataAccess
        @unknown default:
            return .notDetermined
        }
    }
    
    /// Presents the FamilyActivityPicker for selecting applications to restrict.
    ///
    /// - Important: This method is a placeholder signature only.
    ///   FamilyActivityPicker is a SwiftUI view and must be presented in the UI layer.
    ///   Integration example:
    ///   ```swift
    ///   @State private var isPickerPresented = false
    ///   @State private var selectedTokens: Set<ApplicationToken> = []
    ///
    ///   var body: some View {
    ///       Button("Select Apps") { isPickerPresented = true }
    ///           .familyActivityPicker(
    ///               isPresented: $isPickerPresented,
    ///               selection: $selectedTokens,
    ///               configuration: .init()
    ///           )
    ///   }
    ///   ```
    ///
    /// After selection, call `updateSelectedApplications(_:)` to update the manager state.
    ///
    /// - Returns: Void
    func presentPicker() async {
        // Placeholder: UI presentation handled in SwiftUI layer due to FamilyActivityPicker being a SwiftUI View.
    }
    
    /// Updates the selected applications after picker selection.
    ///
    /// - Parameter tokens: The set of selected ApplicationToken objects.
    func updateSelectedApplications(
        _ tokens: Set<ApplicationToken>
    ) {

        print(tokens)

        selectedApplications = tokens

        do {

            let data =
            try JSONEncoder().encode(tokens)

            defaults?.set(
                data,
                forKey: "savedTokens"
            )

        } catch {

            print("Failed saving tokens:", error)
        }
    }
    
    /// Applies blocking restrictions to the selected applications.
    /// Sets the shield applications to the selectedApplications set.
//    func applyBlockingRestrictions() {
//        store.shield.applications = selectedApplications
//        isRestrictionsApplied = true
//    }
    func applyBlockingRestrictions() {

        store.shield.applications =
            selectedApplications

        defaults?.set(
            true,
            forKey: "isBlocked"
        )

        isRestrictionsApplied = true
    }
    
    /// Clears all applied restrictions.
//    func clearRestrictions() {
//        store.shield.applications = []
//        isRestrictionsApplied = false
//    }
    func clearRestrictions() {

        store.shield.applications = nil

        defaults?.set(
            false,
            forKey: "isBlocked"
        )

        isRestrictionsApplied = false
    }
}

#else

import os.log
import Foundation

// Placeholder stand-ins so this file compiles when FamilyControls is unavailable
enum AuthorizationStatus {
    case notDetermined
    case approved
    case denied
}

struct ApplicationToken: Hashable {}

/// Stub implementation when FamilyControls and ManagedSettings are unavailable.
/// Logs usage attempts but allows the app to compile and run on unsupported platforms.
@MainActor
final class FamilyControlsManager: ObservableObject {
    
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var selectedApplications: Set<ApplicationToken> = []
    @Published var isRestrictionsApplied: Bool = false
    @Published var lastError: String? = "FamilyControls framework not available on this platform."
    
    /// Stub method for requesting authorization.
    func requestAuthorization() async {
        lastError = "FamilyControls framework not available on this platform."
        os_log("FamilyControlsManager: requestAuthorization called, but FamilyControls framework is unavailable.", type: .error)
    }
    
    /// Stub placeholder for presentPicker.
    func presentPicker() async {
        lastError = "FamilyControls framework not available on this platform."
        os_log("FamilyControlsManager: presentPicker called, but FamilyControls framework is unavailable.", type: .error)
    }
    
    /// Stub for updating selected applications.
    func updateSelectedApplications(_ tokens: Set<ApplicationToken>) {
        lastError = "FamilyControls framework not available on this platform."
        os_log("FamilyControlsManager: updateSelectedApplications called, but FamilyControls framework is unavailable.", type: .error)
    }
    
    /// Stub for applying blocking restrictions.
    func applyBlockingRestrictions() {
        lastError = "FamilyControls framework not available on this platform."
        os_log("FamilyControlsManager: applyBlockingRestrictions called, but FamilyControls framework is unavailable.", type: .error)
    }
    
    /// Stub for clearing restrictions.
    func clearRestrictions() {
        lastError = "FamilyControls framework not available on this platform."
        os_log("FamilyControlsManager: clearRestrictions called, but FamilyControls framework is unavailable.", type: .error)
    }
}
#endif





