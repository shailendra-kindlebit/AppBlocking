import SwiftUI
import ManagedSettings

#if canImport(FamilyControls)
import FamilyControls
#endif

@MainActor
struct AppBlockingView: View {

    @StateObject private var policy = BlockPolicyManager()
    @StateObject private var family = FamilyControlsManager()

    // MARK: - Saved Storage

    @AppStorage("savedBlocked")
    private var savedBlocked: Bool = false

    @AppStorage("savedReason")
    private var savedReason: String = ""

    @AppStorage("savedRequiresPasscode")
    private var savedRequiresPasscode: Bool = false

    @AppStorage("savedPasscode")
    private var savedPasscode: String = ""

    @AppStorage("savedRestrictionsApplied")
    private var savedRestrictionsApplied: Bool = false

    // MARK: - State

    @State private var passcodeInput: String = ""
    @State private var showAppPickerAlert: Bool = false
    @State private var showError: Bool = false
    @State private var validationMessage: String?
    @State private var familySelection = FamilyActivitySelection()
    @State private var selectedApplications = Set<ApplicationToken>()

    #if canImport(FamilyControls) && canImport(ManagedSettings)
    @State private var isPickerPresented: Bool = false
    #endif

    // MARK: - Constants

    private let minimumPasscodeLength = 4
    private let maximumReasonLength = 120

    // MARK: - Computed Values

    private var reasonBinding: Binding<String> {
        Binding<String>(
            get: {
                policy.reason ?? ""
            },
            set: { newValue in
                let limitedValue = String(newValue.prefix(maximumReasonLength))
                policy.reason = limitedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : limitedValue
            }
        )
    }

    private var isPasscodeValid: Bool {
        !policy.requiresPasscode || passcodeInput.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumPasscodeLength
    }

    private var passcodeValidationText: String? {
        guard policy.requiresPasscode else {
            return nil
        }

        if passcodeInput.isEmpty {
            return "Enter a passcode before enabling protected blocking."
        }

        if passcodeInput.count < minimumPasscodeLength {
            return "Passcode must be at least \(minimumPasscodeLength) characters."
        }

        return nil
    }

    private var selectedAppCountText: String {
        selectedApplications.count == 1 ? "1 app selected" : "\(selectedApplications.count) apps selected"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerView

                        inAppBlockingCard

                        systemBlockingCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                "App picker is not available on this device.",
                isPresented: $showAppPickerAlert
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Request Screen Time authorization on a supported device before selecting apps.")
            }
            .alert(
                "Action Needed",
                isPresented: validationAlertBinding
            ) {
                Button("OK", role: .cancel) {
                    validationMessage = nil
                }
            } message: {
                Text(validationMessage ?? "")
            }
            .alert(
                "Error",
                isPresented: $showError
            ) {
                Button("OK", role: .cancel) {
                    family.lastError = nil
                }
            } message: {
                Text(family.lastError ?? "")
            }
            .onAppear {
                restoreSavedState()
            }
            .onChange(of: policy.isBlocked) {
                savedBlocked = policy.isBlocked
            }
            .onChange(of: policy.reason) {
                savedReason = policy.reason ?? ""
            }
            .onChange(of: policy.requiresPasscode) {
                savedRequiresPasscode = policy.requiresPasscode
            }
            .onChange(of: passcodeInput) { oldValue, newValue in
                let sanitizedValue = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                if sanitizedValue != newValue {
                    passcodeInput = sanitizedValue
                    return
                }

                policy.setPasscode(sanitizedValue.isEmpty ? nil : sanitizedValue)
                savedPasscode = sanitizedValue

                if policy.requiresPasscode, sanitizedValue.count >= minimumPasscodeLength {
                    validationMessage = nil
                }
            }
            .onChange(of: family.isRestrictionsApplied) {
                savedRestrictionsApplied = family.isRestrictionsApplied
            }
            .onChange(of: family.lastError) {
                showError = family.lastError != nil
            }
            #if canImport(FamilyControls) && canImport(ManagedSettings)
            .sheet(isPresented: $isPickerPresented) {
                NavigationStack {
                    FamilyActivityPicker(
                        selection: $familySelection
                    )
                    .navigationTitle("Select Apps")
                    .onChange(of: familySelection) { newValue in
                        selectedApplications = Set(newValue.applicationTokens)
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isPickerPresented = false
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                confirmAppSelection()
                            }
                            .disabled(selectedApplications.isEmpty)
                        }
                    }
                }
            }
            #endif
        }
        .overlay {
            if policy.isBlocked {
                BlockingOverlayView(
                    isPresented: $policy.isBlocked,
                    reason: policy.reason ?? "",
                    requiresPasscode: policy.requiresPasscode,
                    onAttemptUnlock: { inputPasscode in
                        policy.attemptUnlock(with: inputPasscode)
                    }
                )
            }
        }
    }

    // MARK: - Views

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.07, blue: 0.10),
                Color(red: 0.09, green: 0.18, blue: 0.24),
                Color(red: 0.18, green: 0.12, blue: 0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("App Blocking")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)

                    Text("Validate passcodes and app selections before restrictions are applied.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                statusPill(
                    title: policy.isBlocked ? "In-app blocked" : "In-app open",
                    icon: policy.isBlocked ? "lock.fill" : "lock.open.fill",
                    color: policy.isBlocked ? .orange : .green
                )

                statusPill(
                    title: family.isRestrictionsApplied ? "System active" : "System idle",
                    icon: family.isRestrictionsApplied ? "shield.fill" : "shield",
                    color: family.isRestrictionsApplied ? .green : .white.opacity(0.55)
                )
            }
        }
    }

    private var inAppBlockingCard: some View {
        SettingsCard(
            title: "In-App Blocking",
            subtitle: "Control the local blocking overlay and unlock requirements.",
            icon: "app.badge.checkmark"
        ) {
            InAppBlockingSection(
                isBlocked: validatedBlockBinding,
                reason: reasonBinding,
                requiresPasscode: $policy.requiresPasscode,
                passcodeInput: $passcodeInput,
                reasonLimit: maximumReasonLength,
                passcodeValidationText: passcodeValidationText,
                canSimulateSchedule: canApplySystemRestrictions,
                onSetPasscode: { newValue in
                    policy.setPasscode(newValue.isEmpty ? nil : newValue)
                },
                onSimulateSchedule: {
                    applyTemporaryRestrictions()
                }
            )
            .tint(.white)
        }
    }

    private var systemBlockingCard: some View {
        SettingsCard(
            title: "System Blocking",
            subtitle: "Use Screen Time authorization to shield selected apps.",
            icon: "iphone.gen3.radiowaves.left.and.right"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                statusRow

                Divider()
                    .overlay(Color.white.opacity(0.18))

                HStack(spacing: 12) {
                    metricTile(
                        value: "\(selectedApplications.count)",
                        label: "Selected"
                    )

                    metricTile(
                        value: family.isPickerAvailable ? "Ready" : "Locked",
                        label: "Picker"
                    )
                }

                VStack(spacing: 12) {
                    ActionButton(
                        title: "Request Authorization",
                        icon: "lock.shield",
                        style: .primary
                    ) {
                        Task {
                            await family.requestAuthorization()
                        }
                    }

                    ActionButton(
                        title: "Pick Apps",
                        icon: "square.grid.2x2.fill",
                        style: .secondary
                    ) {
                        presentAppPicker()
                    }

                    ActionButton(
                        title: "Apply Restrictions",
                        icon: "shield.fill",
                        style: .primary,
                        isDisabled: !canApplySystemRestrictions
                    ) {
                        applyRestrictions()
                    }

                    ActionButton(
                        title: "Clear Restrictions",
                        icon: "trash.fill",
                        style: .destructive,
                        isDisabled: !family.isRestrictionsApplied
                    ) {
                        clearRestrictions()
                    }
                }
            }
        }
    }

    private var statusRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(family.isPickerAvailable ? Color.green : Color.orange)
                .frame(width: 12, height: 12)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 5) {
                Text("Authorization")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.64))
                    .textCase(.uppercase)

                Text(String(describing: family.authorizationStatus))
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)

                Text(family.isPickerAvailable ? "Picker available for app selection." : "Request authorization before picking apps.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.68))
            }

            Spacer(minLength: 0)
        }
    }

    private var validationAlertBinding: Binding<Bool> {
        Binding<Bool>(
            get: {
                validationMessage != nil
            },
            set: { isPresented in
                if !isPresented {
                    validationMessage = nil
                }
            }
        )
    }

    private var validatedBlockBinding: Binding<Bool> {
        Binding<Bool>(
            get: {
                policy.isBlocked
            },
            set: { newValue in
                if newValue, !validatePasscodeRequirement() {
                    policy.isBlocked = false
                    return
                }

                policy.isBlocked = newValue
            }
        )
    }

    private var canApplySystemRestrictions: Bool {
        family.isPickerAvailable && !selectedApplications.isEmpty
    }

    // MARK: - Actions

    private func restoreSavedState() {
        policy.isBlocked = savedBlocked
        policy.reason = savedReason.isEmpty ? nil : savedReason
        policy.requiresPasscode = savedRequiresPasscode
        passcodeInput = savedPasscode.trimmingCharacters(in: .whitespacesAndNewlines)
        policy.setPasscode(passcodeInput.isEmpty ? nil : passcodeInput)
        family.isRestrictionsApplied = savedRestrictionsApplied

        if savedRestrictionsApplied {
            family.restoreRestrictions()
            selectedApplications = family.selectedApplications
        }
    }

    private func validatePasscodeRequirement() -> Bool {
        guard let message = passcodeValidationText else {
            return true
        }

        validationMessage = message
        return false
    }

    private func validateSystemBlocking() -> Bool {
        guard family.isPickerAvailable else {
            validationMessage = "Request Screen Time authorization before applying restrictions."
            return false
        }

        guard !selectedApplications.isEmpty else {
            validationMessage = "Select at least one app before applying restrictions."
            return false
        }

        return true
    }

    private func presentAppPicker() {
        #if canImport(FamilyControls) && canImport(ManagedSettings)
        guard family.isPickerAvailable else {
            showAppPickerAlert = true
            return
        }

        isPickerPresented = true
        #else
        showAppPickerAlert = true
        #endif
    }

    private func confirmAppSelection() {
        guard !selectedApplications.isEmpty else {
            validationMessage = "Select at least one app to save your selection."
            return
        }

        family.updateSelectedApplications(selectedApplications)
        savedRestrictionsApplied = family.isRestrictionsApplied
        validationMessage = nil

        #if canImport(FamilyControls) && canImport(ManagedSettings)
        isPickerPresented = false
        #endif
    }

    private func applyRestrictions() {
        guard validateSystemBlocking() else {
            return
        }

        family.updateSelectedApplications(selectedApplications)
        family.applyBlockingRestrictions()
        savedRestrictionsApplied = true
    }

    private func applyTemporaryRestrictions() {
        guard validateSystemBlocking() else {
            return
        }

        family.updateSelectedApplications(selectedApplications)
        family.applyBlockingRestrictions()
        savedRestrictionsApplied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
            family.clearRestrictions()
            savedRestrictionsApplied = false
        }
    }

    private func clearRestrictions() {
        family.clearRestrictions()
        savedRestrictionsApplied = false
    }

    // MARK: - Helpers

    private func statusPill(
        title: String,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))

            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(color.opacity(0.18))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.34), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metricTile(
        value: String,
        label: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    AppBlockingView()
}

// MARK: - In-App Blocking Section

struct InAppBlockingSection: View {

    @Binding var isBlocked: Bool
    var reason: Binding<String>
    @Binding var requiresPasscode: Bool
    @Binding var passcodeInput: String

    let reasonLimit: Int
    let passcodeValidationText: String?
    let canSimulateSchedule: Bool
    var onSetPasscode: (String) -> Void
    var onSimulateSchedule: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ToggleRow(
                title: "Blocked",
                subtitle: "Show the local blocking overlay immediately.",
                icon: "lock.rectangle.stack",
                isOn: $isBlocked
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Reason")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.68))
                    .textCase(.uppercase)

                TextField(
                    "Example: Focus time",
                    text: reason,
                    axis: .vertical
                )
                .lineLimit(2, reservesSpace: true)
                .textInputAutocapitalization(.sentences)
                .foregroundColor(.white)
                .padding(14)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

                Text("\(reason.wrappedValue.count)/\(reasonLimit) characters")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.56))
            }

            ToggleRow(
                title: "Requires Passcode",
                subtitle: "Require the saved passcode before unlocking.",
                icon: "key.fill",
                isOn: $requiresPasscode
            )

            VStack(alignment: .leading, spacing: 8) {
                SecureField(
                    "Minimum 4 characters",
                    text: $passcodeInput
                )
                .textContentType(.oneTimeCode)
                .foregroundColor(.white)
                .padding(14)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(passcodeValidationText == nil ? Color.white.opacity(0.16) : Color.orange.opacity(0.9), lineWidth: 1)
                )
                .onChange(of: passcodeInput) { oldValue, newValue in
                    onSetPasscode(newValue)
                }

                if let passcodeValidationText {
                    Label(passcodeValidationText, systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            ActionButton(
                title: "Start 5-Minute System Block",
                icon: "timer",
                style: .warning,
                isDisabled: !canSimulateSchedule
            ) {
                onSimulateSchedule()
            }

            Text(canSimulateSchedule ? "Temporarily shields the selected apps for 5 minutes." : "Select apps and request authorization to use the temporary block.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.64))
        }
    }
}

// MARK: - Shared UI

struct SettingsCard<Content: View>: View {

    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            content
        }
        .padding(18)
        .background(Color.white.opacity(0.11))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct ToggleRow: View {

    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

struct ActionButton: View {

    enum Style {
        case primary
        case secondary
        case destructive
        case warning
    }

    let title: String
    let icon: String
    let style: Style
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .frame(width: 22)

                Text(title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isDisabled ? 0.45 : 1)
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return Color(red: 0.12, green: 0.38, blue: 0.48)
        case .secondary:
            return Color.white.opacity(0.14)
        case .destructive:
            return Color(red: 0.58, green: 0.16, blue: 0.16)
        case .warning:
            return Color(red: 0.68, green: 0.34, blue: 0.10)
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return Color.cyan.opacity(0.28)
        case .secondary:
            return Color.white.opacity(0.18)
        case .destructive:
            return Color.red.opacity(0.34)
        case .warning:
            return Color.orange.opacity(0.38)
        }
    }
}
