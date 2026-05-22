import SwiftUI

public struct BlockingOverlayView: View {
    @Binding public var isPresented: Bool
    public let reason: String?
    public let requiresPasscode: Bool
    public let onAttemptUnlock: ((String) -> Bool)?
    
    @State private var passcode: String = ""
    @State private var failedAttempt: Bool = false
    
    public init(
        isPresented: Binding<Bool>,
        reason: String? = nil,
        requiresPasscode: Bool,
        onAttemptUnlock: ((String) -> Bool)? = nil
    ) {
        self._isPresented = isPresented
        self.reason = reason
        self.requiresPasscode = requiresPasscode
        self.onAttemptUnlock = onAttemptUnlock
    }
    
    public var body: some View {
        ZStack {
            // Background with blur and overlay
            VisualEffectView(effect: UIBlurEffect(style: .regular))
                .ignoresSafeArea()
                .overlay(
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                )
            
            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(.primary)
                    .accessibilityHidden(true)
                
                Text("Blocked")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundColor(.primary)
                    .accessibilityAddTraits(.isHeader)
                
                if let reason = reason, !reason.isEmpty {
                    Text(reason)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 32)
                        .accessibilityLabel("Reason: \(reason)")
                }
                
                if requiresPasscode {
                    VStack(spacing: 12) {
                        SecureField("Enter passcode", text: $passcode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 240)
                            .accessibilityLabel("Passcode entry field")
                            .accessibilityHint("Enter your passcode to unlock")
                            .submitLabel(.done)
                            .onSubmit {
                                attemptUnlock()
                            }
                        
                        Button(action: attemptUnlock) {
                            Text("Unlock")
                                .frame(maxWidth: 240)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(passcode.isEmpty)
                        .accessibilityLabel("Unlock button")
                        .accessibilityHint("Attempt to unlock with entered passcode")
                        
                        if failedAttempt {
                            if #available(iOS 17.0, *) {

                                Text("Incorrect passcode. Please try again.")
                                    .foregroundColor(.red)
                                    .font(.footnote)

                            } else {

                                Text("Incorrect passcode. Please try again.")
                                    .foregroundColor(.red)
                                    .font(.footnote)
                            }
                        }
                    }
                }
            }
            .padding(32)
        }
        .accessibilityElement(children: .contain)
    }
    
    private func attemptUnlock() {
        if let onAttemptUnlock = onAttemptUnlock {
            if onAttemptUnlock(passcode) {
                isPresented = false
                passcode = ""
                failedAttempt = false
            } else {
                failedAttempt = true
            }
        } else {
            // If no callback provided, just dismiss on any attempt
            isPresented = false
        }
    }
}

// UIKit VisualEffectView wrapper for SwiftUI background blur
fileprivate struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: effect)
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}


    struct PreviewWrapper: View {
        @State private var isPresented = true
        @State private var unlocked = false
        
        var body: some View {
            ZStack {
                Color.green.opacity(0.3)
                    .ignoresSafeArea()
                
                if unlocked {
                    Text("Unlocked Content")
                        .font(.title)
                        .foregroundColor(.green)
                } else {
                    Text("Locked Content")
                        .font(.title)
                        .foregroundColor(.gray)
                }
                
                if isPresented {
                    BlockingOverlayView(
                        isPresented: $isPresented,
                        reason: "Your session has expired. Please enter your passcode to continue.",
                        requiresPasscode: true,
                        onAttemptUnlock: { input in
                            let correctPasscode = "1234"
                            let success = input == correctPasscode
                            if success {
                                unlocked = true
                            }
                            return success
                        }
                    )
                }
            }
        }
    }
    
