//
//  AppDelegate.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-03.
//

import CloudKit
import FirebaseCore
import Foundation
import IceCream
import Nuke
import RealmSwift
import UIKit

class STTAppDelegate: NSObject, UIApplicationDelegate {
    var syncEngine: SyncEngine?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Register BG Tasks
        STTScheduler.shared.registerTasks()

        // Set Default UD Values
        UserDefaults.standard.register(defaults: STTUserDefaults())
        UDSync.sync()

        // Nuke Requests
        let nukeConfig = DataLoader.defaultConfiguration
        nukeConfig.headers.add(.userAgent(Preferences.standard.userAgent))
        nukeConfig.httpCookieStorage = HTTPCookieStorage.shared

        // Image Pipeline
        let pipeline = ImagePipeline {
            let dataCache = try? DataCache(name: "com.ceres.suwatte.nuke_cache")
            let imageCache = ImageCache.shared
            dataCache?.sizeLimit = 1024 * 1024 * 1024 // 1 GB
            imageCache.costLimit = 200 * 1024 * 1024 // 500 MB
            imageCache.countLimit = 100 // 100 Images
            $0.dataLoader = DataLoader(configuration: nukeConfig)
            $0.imageCache = imageCache
            $0.dataCache = dataCache
        }

        ImagePipeline.shared = pipeline

        // Notification Center
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
        }

        // Realm
        var config = Realm.Configuration(schemaVersion: UInt64(SCHEMA_VERSION))
        let directory = FileManager.default.applicationSupport.appendingPathComponent("Database", isDirectory: true)
        if !directory.exists {
            directory.createDirectory()
        }
        config.fileURL = directory.appendingPathComponent("suwatte_db.realm")
        Realm.Configuration.defaultConfiguration = config

        // Sync Engine
        syncEngine = SyncEngine(objects: [
            SyncObject(type: StoredTag.self),
            SyncObject(type: StoredProperty.self, uListElementType: StoredTag.self),
            SyncObject(type: StoredContent.self, uListElementType: StoredProperty.self),
            SyncObject(type: LibraryEntry.self),
            SyncObject(type: StoredRunnerList.self),
            SyncObject(type: StoredRunnerObject.self),
            SyncObject(type: InteractorStoreObject.self),
            SyncObject(type: CustomThumbnail.self),
            SyncObject(type: ContentLink.self),
            SyncObject(type: UpdatedSearchHistory.self),
            SyncObject(type: TrackerLink.self),
            SyncObject(type: StoredOPDSServer.self),
            SyncObject(type: LibraryCollectionFilter.self),
            SyncObject(type: LibraryCollection.self),
            SyncObject(type: ChapterReference.self),
            SyncObject(type: ProgressMarker.self),
            SyncObject(type: UpdatedBookmark.self),
            SyncObject(type: ReadLater.self),
            SyncObject(type: StreamableOPDSContent.self),
            SyncObject(type: ArchivedContent.self),
            SyncObject(type: ChapterBookmark.self),
            SyncObject(type: UserReadingStatistic.self),
        ])

        application.registerForRemoteNotifications()

        // Analytics
        FirebaseApp.configure()

        return true
    }

    // Reference: https://github.com/leoz/IceCream/blob/master/Example/IceCream_Example/AppDelegate.swift
    func application(_: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let dict = userInfo as? [String: NSObject], let notification = CKNotification(fromRemoteNotificationDictionary: dict), let subscriptionID = notification.subscriptionID, IceCreamSubscription.allIDs.contains(subscriptionID) {
            NotificationCenter.default.post(name: Notifications.cloudKitDataDidChangeRemotely.name, object: nil, userInfo: userInfo)
            completionHandler(.newData)
        }
    }
}
