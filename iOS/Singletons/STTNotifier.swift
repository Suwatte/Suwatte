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
    static var shared = STTNotifier()

    func scheduleUpdateNotification(count: Int) {
        // Content
        let content = UNMutableNotificationContent()
        content.title = "New Chapters Available"
        content.body = "\(count) New Update\(count == 1 ? "" : "s") in your library"
        let currentBadgeCount = UIApplication.shared.applicationIconBadgeNumber
        content.badge = (count + currentBadgeCount) as NSNumber
        content.sound = UNNotificationSound.default

        // Request
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "stt-update-notif", content: content, trigger: trigger)

        // Schedule
        let center = UNUserNotificationCenter.current()
        center.add(request)
    }

    func clearBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}
