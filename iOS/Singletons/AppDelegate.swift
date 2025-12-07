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
            imageCache.costLimit = 1024 * 1024 * 500 // 500 MB
            $0.dataLoader = DataLoader(configuration: nukeConfig)
            $0.imageCache = imageCache
            $0.dataCache = dataCache
            $0.dataCachePolicy = .automatic
            $0.isStoringPreviewsInMemoryCache = false
        }

        ImagePipeline.shared = pipeline

        // Realm
        var config = Realm.Configuration(schemaVersion: UInt64(SCHEMA_VERSION), migrationBlock: { migration, oldSchemaVersion in
            if oldSchemaVersion < 16 {
                migration.renameProperty(onType: ProgressMarker.className(), from: "currentChapter", to: "chapter")
                MigrationHelper.migrateContentLinks(migration: migration)
                MigrationHelper.migrateInteractorStoreObjects(migration: migration)
            }
        }, shouldCompactOnLaunch: { totalBytes, usedBytes in
            (Double(usedBytes) / Double(totalBytes)) < 0.5
        })

        let directory = FileManager.default.applicationSupport.appendingPathComponent("Database", isDirectory: true)
        if !directory.exists {
            directory.createDirectory()
        }
        config.fileURL = directory.appendingPathComponent("suwatte_db.realm")
        Realm.Configuration.defaultConfiguration = config

        // Analytics
        FirebaseApp.configure()

        return true
    }
}
