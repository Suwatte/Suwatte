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

    func updateUIViewController(_: IVPagingController, context _: Context) {}
}
