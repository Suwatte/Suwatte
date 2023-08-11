//
//  VerticalPaged+Representable.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-09.
//

import SwiftUI

struct VerticalPagedViewer: UIViewControllerRepresentable {
    @EnvironmentObject private var model: IVViewModel
    typealias UIViewControllerType = IVPagingController
    
    func makeUIViewController(context: Context) -> IVPagingController {
        let controller = IVPagingController(collectionViewLayout: UICollectionViewFlowLayout())
        controller.model = model
        controller.isVertical = true
        return controller
    }
    
    func updateUIViewController(_ uiViewController: IVPagingController, context: Context) {}
}
