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
//        let cache = ImageCache.default
//        cache.memoryStorage.config.totalCostLimit = 500 * 1024 * 1024
//        cache.memoryStorage.config.countLimit = 150
//        cache.diskStorage.config.sizeLimit = 1000 * 1024 * 1024

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
        let config = Realm.Configuration(schemaVersion: UInt64(SCHEMA_VERSION),
                                         migrationBlock: { migration, oldSchemaVersion in
                                             if oldSchemaVersion < 3 {
                                                 migration.renameProperty(onType: ChapterMarker.className(), from: "total", to: "totalPageCount")
                                                 migration.renameProperty(onType: ChapterMarker.className(), from: "last", to: "lastPageRead")
                                             }
                                             if oldSchemaVersion < 4 {
                                                 migration.renameProperty(onType: StoredChapter.className(), from: "sourceIndex", to: "index")
                                             }
                                         })
        Realm.Configuration.defaultConfiguration = config

        return true
    }
}
