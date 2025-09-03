//
//  Paged+Representable.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import SwiftUI

struct PagedImageViewer: UIViewControllerRepresentable {
    @EnvironmentObject private var model: IVViewModel
    typealias UIViewControllerType = IVPagingController

    func makeUIViewController(context _: Context) -> IVPagingController {
        let controller = IVPagingController(collectionViewLayout: UICollectionViewFlowLayout())
        controller.model = model
        return controller
    }

    func updateUIViewController(_ controller: IVPagingController, context _: Context) {
        guard model.pendingState != nil, model.isDoublePaged != true, controller.isLoaded, controller.loadingTask == nil else { return }
        controller.hardReset()
        controller.startup()
    }
}
