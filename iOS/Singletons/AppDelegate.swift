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
    private var syncEngine: SyncEngine?
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
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
        var config = Realm.Configuration(schemaVersion: UInt64(SCHEMA_VERSION), migrationBlock: { migration, oldSchemaVersion in
            if oldSchemaVersion < 16 {
                MigrationHelper.migrateContentLinks(migration: migration)
            }
            if oldSchemaVersion < 18 {
                MigrationHelper.migrateProgressMarker(migration: migration)
            }

            if oldSchemaVersion < 23 {
                /*migration.enumerateObjects(ofType: ContentLink.className()) { oldContentLinkObject, newContentLinkObject in
                    guard let oldContentLinkObject = oldContentLinkObject else { return }

                    let linkLibraryEntryId = oldContentLinkObject["libraryEntryId"] as! String
                    let linkContentId = oldContentLinkObject["contentId"] as! String

                    var foundLibraryEntryObject: MigrationObject?
                    var foundContentObject: MigrationObject?

                    migration.enumerateObjects(ofType: LibraryEntry.className()) { _, libraryEntryObject in
                        if let libraryEntryId = libraryEntryObject!["id"] as? String {

                            if libraryEntryId == linkLibraryEntryId {

                                foundLibraryEntryObject = libraryEntryObject
                            }
                        }
                    }

                    migration.enumerateObjects(ofType: StoredContent.className()) { _, contentObject in
                        if let contentId = contentObject!["id"] as? String {

                            if contentId == linkContentId {

                                foundContentObject = contentObject
                            }
                        }
                    }

                    if foundContentObject != nil && foundLibraryEntryObject != nil {
                        newContentLinkObject!["entry"] = foundLibraryEntryObject
                        newContentLinkObject!["content"] = foundContentObject
                    }
                }*/
            }
        })

        let directory = FileManager.default.applicationSupport.appendingPathComponent("Database", isDirectory: true)
        if !directory.exists {
            directory.createDirectory()
        }
        config.fileURL = directory.appendingPathComponent("suwatte_db.realm")
        Realm.Configuration.defaultConfiguration = config

        try! Realm.performMigration()

        // Analytics
        FirebaseApp.configure()

        return true
    }

    //@MainActor
    func convertMutableSetToSwiftSet(realmMutableSet: MutableSet<String>, completion: @escaping (Set<String>) -> Void) {
        let swiftSet: Set<String> = Set(realmMutableSet)

        completion(swiftSet)
    }
}
