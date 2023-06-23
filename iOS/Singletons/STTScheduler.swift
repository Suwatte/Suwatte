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

    let update_task = "com.ceres.suwatte.fetch_updates"
    let backup_task = "com.ceres.suwatte.auto_backup"

    func registerTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: update_task, using: nil) { task in
            self.handleLibraryUpdate(task: task as! BGProcessingTask)
        }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: backup_task, using: nil) { task in
            self.handleBackUpTask(task: task as! BGProcessingTask)
        }

        Logger.shared.log("[STTScheduler] Background Tasks Registered")
    }

    func scheduleAll() {
        scheduleLibraryUpdate()
        scheduleBackUp()
    }

    func scheduleLibraryUpdate() {
        let request = BGProcessingTaskRequest(identifier: update_task)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger.shared.error("[STTScheduler] [\(update_task)] Failed To Schedule : \(error)")
        }
    }

    func scheduleBackUp() {
        let request = BGProcessingTaskRequest(identifier: backup_task)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger.shared.error("[STTScheduler] [\(backup_task)] Failed To Schedule : \(error)")
        }
    }

    func handleBackUpTask(task: BGProcessingTask) {
        Logger.shared.log("[STTScheduler] [\(backup_task)] Task Called")
        task.expirationHandler = { [weak self] in
            Logger.shared.log("[STTScheduler] [\(self?.backup_task ?? #function)] Expiration Handler Triggered. Exiting...")
            task.setTaskCompleted(success: false)
        }

        let lastChecked = UserDefaults.standard.object(forKey: STTKeys.LastAutoBackup) as? Date ?? .distantPast
        let next = Calendar.current.date(
            byAdding: .day,
            value: 7,
            to: lastChecked
        )! // 7 Days Interval

        if Date.now < next {
            task.setTaskCompleted(success: true)
            Logger.shared.log("[STTScheduler] [\(backup_task)] AutoBackup Interval Not Met")
            return
        }

        do {
            try BackupManager.shared.save(name: "AUTO_BACKUP")
            Logger.shared.log("[STTScheduler] [\(backup_task)] AutoBackup Created")
            UserDefaults.standard.set(Date(), forKey: STTKeys.LastAutoBackup)
            task.setTaskCompleted(success: true)
        } catch {
            Logger.shared.log("[STTScheduler] [\(backup_task)] Failed to create automatic backup \(error.localizedDescription)")
            task.setTaskCompleted(success: false)
        }
    }

    func handleLibraryUpdate(task: BGProcessingTask) {
        Logger.shared.log("[STTScheduler] [\(update_task)] Task Called")

        let now = Date()
        let interval = STTUpdateInterval(rawValue: UserDefaults.standard.integer(forKey: STTKeys.UpdateInterval)) ?? .oneHour
        let timeInterval = TimeInterval(interval.interval)
        let lastChecked = UserDefaults.standard.object(forKey: STTKeys.LastFetchedUpdates) as? Date ?? .distantPast

        guard now > (lastChecked + timeInterval) else {
            Logger.shared.log("[STTScheduler] [\(update_task)] Update Interval not met, Exiting...")
            task.setTaskCompleted(success: true)
            return
        }

        let updateTask = Task { [weak self] in
            let updates = await SourceManager.shared.fetchLibraryUpdates()

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
