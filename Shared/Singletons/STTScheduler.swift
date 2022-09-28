//
//  STTScheduler.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-03.
//

import BackgroundTasks
import Foundation
import UserNotifications

// Reference: https://developer.apple.com/videos/play/wwdc2019/707/?time=1131

class STTScheduler {
    static var shared = STTScheduler()

    var update_task = "com.suwatte.fetch_updates"

    func registerTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: update_task, using: nil) { task in
            self.handleLibraryUpdate(task: task as! BGProcessingTask)
        }
        Logger.shared.log("[STTScheduler] Background Tasks Registered")
    }

    func scheduleLibraryUpdate() {
        let request = BGProcessingTaskRequest(identifier: update_task)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger.shared.error("[STTScheduler] [\(update_task)] Failed To Schedule : \(error)")
        }
    }

    func handleLibraryUpdate(task: BGProcessingTask) {
        Logger.shared.log("[STTScheduler] [\(update_task)] Task Called")

        let now = Date()
        let oneHour = TimeInterval(1 * 60 * 60)
        let lastChecked = UserDefaults.standard.object(forKey: STTKeys.LastFetchedUpdates) as? Date ?? .distantPast

        guard now > (lastChecked + oneHour) else {
            Logger.shared.log("[STTScheduler] [\(update_task)] Update Interval not met, Exiting...")
            task.setTaskCompleted(success: true)
            return
        }

        let updateTask = Task { @MainActor [weak self] in
            let updates = await DaisukeEngine.shared.handleBackgroundLibraryUpdate()

            if updates > 0 {
                STTNotifier.shared.scheduleUpdateNotification(count: updates)
            }
            Logger.shared.log("[STTScheduler] [\(self?.update_task ?? #function)] Update Interval not met, Exiting...")
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = { [weak self] in
            Logger.shared.log("[STTScheduler] [\(self?.update_task ?? #function)] Expiration Handler Triggered. Exiting...")
            updateTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
