import Foundation

#if canImport(FamilyControls) && canImport(ManagedSettings)
import FamilyControls
import ManagedSettings

/// Manages FamilyControls and ManagedSettings operations for app authorization and restrictions.
/// 
/// - Note: Usage of FamilyControls requires the `com.apple.developer.family-controls` entitlement.
/// - Note: Restriction APIs require user authorization and are only available on supported platforms.
/// - Note: UI presentation for selecting applications must be handled in SwiftUI using `FamilyActivityPicker`.
@MainActor
final class FamilyControlsManager: ObservableObject {
    
    @Published var authorizationStatus: AuthorizationCenter.AuthorizationStatus = .notDetermined
    @Published var selectedApplications: Set<ApplicationToken> = []
    @Published var isRestrictionsApplied: Bool = false
    @Published var lastError: String? = nil
    
    private let authorizationCenter = AuthorizationCenter.shared
    private let store = ManagedSettingsStore()
    
    /// Requests authorization for managing family controls.
    func requestAuthorization() async {
        do {
            let status = try await authorizationCenter.requestAuthorization()
            authorizationStatus = status
        } catch {
            lastError = "Authorization request failed: \(error.localizedDescription)"
            authorizationStatus = .notDetermined
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
    func updateSelectedApplications(_ tokens: Set<ApplicationToken>) {
        selectedApplications = tokens
    }
    
    /// Applies blocking restrictions to the selected applications.
    /// Sets the shield applications to the selectedApplications set.
    func applyBlockingRestrictions() {
        store.shield.applications = selectedApplications
        isRestrictionsApplied = true
    }
    
    /// Clears all applied restrictions.
    func clearRestrictions() {
        store.shield.applications = []
        isRestrictionsApplied = false
    }
}

#else

import os.log
import Foundation

/// Stub implementation when FamilyControls and ManagedSettings are unavailable.
/// Logs usage attempts but allows the app to compile and run on unsupported platforms.
@MainActor
final class FamilyControlsManager: ObservableObject {
    
    @Published var authorizationStatus: AuthorizationCenter.AuthorizationStatus = .notDetermined
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
