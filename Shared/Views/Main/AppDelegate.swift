//
//  AppDelegate.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-03.
//

import Foundation
import Kingfisher
import RealmSwift
import UIKit

class STTAppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // KF Cache
        let cache = ImageCache.default
        cache.memoryStorage.config.totalCostLimit = 500 * 1024 * 1024 // 500 MB
        cache.memoryStorage.config.countLimit = 15 // 15
        cache.diskStorage.config.sizeLimit = 1000 * 1024 * 1024 // 1GB

        let kingfisherManagerSession = KingfisherManager.shared.downloader.sessionConfiguration
        kingfisherManagerSession.httpCookieStorage = HTTPCookieStorage.shared
        KingfisherManager.shared.downloader.sessionConfiguration = kingfisherManagerSession

        // Register BG Tasks
        STTScheduler.shared.registerTasks()

        // Set Default UD Values
        UserDefaults.standard.register(defaults: STTUserDefaults)

        // Notification Center
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
            } else {
                ToastManager.shared.display(.error(nil, "Notifications Disabled"))
            }
        }

        // Realm
        var config = Realm.Configuration(schemaVersion: UInt64(SCHEMA_VERSION))
        let directory = FileManager.default.applicationSupport.appendingPathComponent("Database", isDirectory: true)
        if !directory.exists {
            directory.createDirectory()
        }
        config.fileURL = directory.appendingPathComponent("suwatte_db.realm")
        Realm.Configuration.defaultConfiguration = config

        return true
    }
}
