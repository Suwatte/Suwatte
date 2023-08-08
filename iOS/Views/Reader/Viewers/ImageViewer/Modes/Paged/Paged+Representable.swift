//
//  Paged+Representable.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import SwiftUI
import UIKit


struct PagedImageViewer : UIViewControllerRepresentable {
    @EnvironmentObject private var model: IVViewModel
    typealias UIViewControllerType = PagedViewerController
    
    func makeUIViewController(context: Context) -> PagedViewerController {
        let controller = PagedViewerController(collectionViewLayout: HImageViewerLayout())
        
        let collectionView = controller.collectionView
        guard let collectionView else {
            Logger.shared.warn("Incomplete Controller Setup", "PagedImageViewer")
            return controller
        }
        
        context.coordinator.controller = controller
        controller.keyboardNavigationDelegate = context.coordinator
        context.coordinator.model = model
        collectionView.isPagingEnabled = true
        collectionView.isHidden = true
        collectionView.scrollsToTop = false
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: PagedViewerController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}
