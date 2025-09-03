//
//  STTPhotoAlbum.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-15.
//

import Foundation
import Photos
import UIKit

@objc class STTPhotoAlbum: NSObject {
    /// Default album title.
    static let defaultTitle = "Suwatte"

    /// Singleton
    static let shared = STTPhotoAlbum(STTPhotoAlbum.defaultTitle)

    /// The album title to use.
    private(set) var albumTitle: String

    /// This album's asset collection
    var assetCollection: PHAssetCollection?

    /// Initialize a new instance of this class.
    ///
    /// - Parameter title: Album title to use.
    init(_ title: String) {
        albumTitle = title
        super.init()
    }

    /// Save the image to this app's album.
    ///
    /// - Parameter image: Image to save.
    func save(_ image: UIImage?) {
        guard let image = image else { return }

        // Request authorization and create the album
        requestAuthorizationIfNeeded { _ in
            // If it all went well, we've got our asset collection
            guard let assetCollection = self.assetCollection else { return }

            PHPhotoLibrary.shared().performChanges({
                // Make sure that there's no issue while creating the request
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                guard let placeholder = request.placeholderForCreatedAsset,
                      let albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection)
                else {
                    return
                }

                let enumeration: NSArray = [placeholder]
                albumChangeRequest.addAssets(enumeration)

            }, completionHandler: { _, _ in
                ToastManager.shared.display(.info("Saved Image"))
            })
        }
    }
}

extension STTPhotoAlbum {
    /// Request authorization and create the album if that went well.
    ///
    /// - Parameter completion: Called upon completion.
    func requestAuthorizationIfNeeded(_ completion: @escaping ((_ success: Bool) -> Void)) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                completion(false)
                return
            }

            // Try to find an existing collection first so that we don't create duplicates
            if let collection = self.fetchAssetCollectionForAlbum() {
                self.assetCollection = collection
                completion(true)

            } else {
                self.createAlbum(completion)
            }
        }
    }

    /// Creates an asset collection with the album name.
    ///
    /// - Parameter completion: Called upon completion.
    func createAlbum(_ completion: @escaping ((_ success: Bool) -> Void)) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumTitle)

        }) { success, error in
            defer {
                completion(success)
            }

            guard error == nil else {
                Logger.shared.error("[STTPhotoAlbum] \(error?.localizedDescription ?? "An Error Occurred")")
                return
            }

            self.assetCollection = self.fetchAssetCollectionForAlbum()
        }
    }

    /// Fetch the asset collection matching this app's album.
    ///
    /// - Returns: An asset collection if found.
    func fetchAssetCollectionForAlbum() -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumTitle)

        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        return collection.firstObject
    }
}
