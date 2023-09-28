//
//  STTNotifier.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-04.
//

import Foundation
import UIKit
import UserNotifications

class STTNotifier {
    static let shared = STTNotifier()

    @MainActor
    func scheduleUpdateNotification(count: Int) {
        // Content
        let content = UNMutableNotificationContent()
        content.title = "New Chapters Available"
        content.body = "\(count) Update\(count != 1 ? "s" : "") in your library"
        let currentBadgeCount = UIApplication.shared.applicationIconBadgeNumber
        content.badge = (count + currentBadgeCount) as NSNumber
        content.sound = UNNotificationSound.default

        // Request
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "com.ceres.suwatte.library_update", content: content, trigger: trigger)

        // Schedule
        let center = UNUserNotificationCenter.current()
        center.add(request)
    }

    @MainActor
    func clearBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}
