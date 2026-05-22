import SwiftUI
import Foundation

@MainActor
final class BlockPolicyManager: ObservableObject {
    @Published var isBlocked: Bool = false
    @Published var reason: String? = nil
    @Published var requiresPasscode: Bool = false
    
    private var passcode: String? = nil
    
    /// Sets the passcode required to unblock.
    /// - Parameter new: The new passcode string or nil to clear it.
    func setPasscode(_ new: String?) {
        passcode = new
    }
    
    /// Blocks the app with an optional reason and passcode requirement.
    /// - Parameters:
    ///   - reason: Optional string explaining why the block is active.
    ///   - requiresPasscode: Whether a passcode is required to unblock.
    func block(reason: String? = nil, requiresPasscode: Bool = false) {
        self.reason = reason
        self.requiresPasscode = requiresPasscode
        self.isBlocked = true
    }
    
    /// Unblocks the app and clears block state.
    func unblock() {
        self.isBlocked = false
        self.reason = nil
        self.requiresPasscode = false
    }
    
    /// Attempts to unlock using the provided code.
    /// - Parameter code: The passcode string to attempt unlocking.
    /// - Returns: True if unlock succeeded, false otherwise.
    func attemptUnlock(with code: String) -> Bool {
        guard requiresPasscode, let stored = passcode else {
            // No passcode required or set, unlock immediately
            unblock()
            return true
        }
        
        if code == stored {
            unblock()
            return true
        } else {
            return false
        }
    }
    
    /// Toggles the block state based on a schedule defined by start and end hour.
    /// Supports wrap-around if endHour < startHour.
    /// - Parameters:
    ///   - currentDate: The current date, defaults to now.
    ///   - startHour: The starting hour (0-23) to begin blocking.
    ///   - endHour: The ending hour (0-23) to end blocking.
    func toggleForSchedule(currentDate: Date = .now, startHour: Int, endHour: Int) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentDate)
        
        let shouldBlock: Bool
        if startHour <= endHour {
            // Normal range
            shouldBlock = (hour >= startHour && hour < endHour)
        } else {
            // Wrap-around range, e.g. start 22, end 6
            shouldBlock = (hour >= startHour || hour < endHour)
        }
        
        isBlocked = shouldBlock
        if !shouldBlock {
            reason = nil
            requiresPasscode = false
        }
    }
}

/*
 Example usage preview/mock:

 let manager = BlockPolicyManager()
 manager.setPasscode("1234")
 manager.block(reason: "Parental Control Active", requiresPasscode: true)
 
 print(manager.isBlocked) // true
 print(manager.reason)    // "Parental Control Active"
 
 let unlockSuccess = manager.attemptUnlock(with: "1234")
 print(unlockSuccess)     // true
 print(manager.isBlocked) // false
 
 // Schedule blocking from 22:00 to 06:00
 manager.toggleForSchedule(currentDate: Date(), startHour: 22, endHour: 6)
 print(manager.isBlocked) // depends on current hour
*/
