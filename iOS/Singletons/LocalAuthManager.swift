//
//  LocalAuthManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-08.
//

import Combine
import Foundation
import LocalAuthentication

final class LocalAuthManager: ObservableObject {
    static let shared = LocalAuthManager()

    var subscriptions = Set<AnyCancellable>()
    @Published var isAuthenticating = false

    // Init
    init() {
        subscribe()
    }

    // Keys
    var LastVerified: Date {
        UserDefaults.standard.object(forKey: STTKeys.LastVerifiedAuth) as? Date ?? Date()
    }

    var Timeout: TimeoutDuration {
        let raw = UserDefaults.standard.integer(forKey: STTKeys.TimeoutDuration)

        return TimeoutDuration(rawValue: raw)!
    }

    var isExpired: Bool {
        let lastVerified = LastVerified
        let interval = abs(lastVerified.timeIntervalSinceNow)
        return interval >= Double(Timeout.durationInSeconds)
    }

    enum TimeoutDuration: Int, CaseIterable, UserDefaultsSerializable {
        case immediately, afer5, after15, after30, after1h, after2h, after5h, after12h, after1d

        var description: String {
            switch self {
            case .immediately:
                return "Immediately"
            case .afer5:
                return "After 5 Minutes"
            case .after15:
                return "After 15 Minutes"
            case .after30:
                return "After 30 Minutes"
            case .after1h:
                return "After 1 Hour"
            case .after2h:
                return "After 2 Hours"
            case .after5h:
                return "After 5 Hours"
            case .after12h:
                return "After 12 Hours"
            case .after1d:
                return "After 1 Day"
            }
        }

        var durationInSeconds: Int {
            switch self {
            case .immediately:
                return 1
            case .afer5:
                return 5 * 60
            case .after15:
                return 15 * 60
            case .after30:
                return 30 * 60
            case .after1h:
                return 60 * 60
            case .after2h:
                return 120 * 60
            case .after5h:
                return 5 * 60 * 60
            case .after12h:
                return 15 * 60 * 60
            case .after1d:
                return 24 * 60 * 60
            }
        }
    }

    func verify() {
        if !UserDefaults.standard.bool(forKey: STTKeys.LibraryAuth) {
            return
        }
        if isExpired {
            authenticate(toggleOnFail: false)
        }
    }

    func authenticate(toggleOnFail: Bool = true) {
        isAuthenticating = true

        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Please authenticate yourself to unlock your protected content."

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                Task { @MainActor in
                    if !success {
                        self.handleFail(toggle: toggleOnFail)
                        return
                    }
                    self.handleSuccess()
                }
            }
        } else {
            ToastManager.shared.error(error?.localizedDescription ?? "An Error Occurred")
            handleFail(toggle: toggleOnFail)
        }
    }

    func subscribe() {
        Preferences.standard.preferencesChangedSubject
            .filter { changedKeyPath in
                changedKeyPath == \Preferences.protectContent
            }.sink { _ in
                if !self.isAuthenticating {
                    self.authenticate()
                }
            }.store(in: &subscriptions)
    }

    func handleSuccess() {
        UserDefaults.standard.set(Date(), forKey: STTKeys.LastVerifiedAuth)
        isAuthenticating = false
    }

    func handleFail(toggle: Bool) {
        if toggle {
            Preferences.standard.protectContent.toggle()
        }
        isAuthenticating = false
    }

    func handleTimeoutChange(_: TimeoutDuration) {}
}
