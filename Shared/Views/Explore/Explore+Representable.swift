//
//  Explore+Representable.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-30.
//

import SwiftUI

struct ExploreCollectionViewRepresentable: UIViewControllerRepresentable {
    @EnvironmentObject var model: ExploreView.ViewModel
    @AppStorage(STTKeys.TileStyle) var tileStyle = TileStyle.SEPARATED
    func makeUIViewController(context _: Context) -> some ExploreCollectionsController {
        let controller = ExploreCollectionsController(collectionViewLayout: UICollectionViewLayout())
        controller.source = model.source
        controller.model = model
        controller.tileStyle = tileStyle
        return controller
    }

    func updateUIViewController(_ controller: UIViewControllerType, context _: Context) {
        if tileStyle != controller.tileStyle {
            controller.tileStyle = tileStyle
        }
    }
}
