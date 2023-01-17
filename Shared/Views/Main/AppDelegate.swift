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
import Nuke

class STTAppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        // Register BG Tasks
        STTScheduler.shared.registerTasks()

        // Set Default UD Values
        UserDefaults.standard.register(defaults: STTUserDefaults)
        
        // KF Cache
        let cache = Kingfisher.ImageCache.default
        cache.memoryStorage.config.totalCostLimit = 500 * 1024 * 1024 // 500 MB
        cache.memoryStorage.config.countLimit = 15 // 15
        cache.diskStorage.config.sizeLimit = 1000 * 1024 * 1024 // 1GB

        // KF Requests
        let kingfisherManagerSession = KingfisherManager.shared.downloader.sessionConfiguration
        kingfisherManagerSession.httpCookieStorage = HTTPCookieStorage.shared
        kingfisherManagerSession.headers.add(.userAgent(Preferences.standard.userAgent))
        KingfisherManager.shared.downloader.sessionConfiguration = kingfisherManagerSession
        
        // Nuke Requests
        let nukeConfig = DataLoader.defaultConfiguration
        nukeConfig.headers.add(.userAgent(Preferences.standard.userAgent))
        nukeConfig.httpCookieStorage = HTTPCookieStorage.shared

        let pipeline = ImagePipeline {
            $0.dataLoader = DataLoader(configuration: nukeConfig)
            $0.imageCache = Nuke.ImageCache.shared
        }

        ImagePipeline.shared = pipeline
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
