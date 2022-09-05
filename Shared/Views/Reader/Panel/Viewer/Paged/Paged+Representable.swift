//
//  Paged+Representable.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-30.
//

import SwiftUI

struct PagedViewer: UIViewControllerRepresentable {
    @EnvironmentObject var model: ReaderView.ViewModel

    func makeUIViewController(context _: Context) -> some UIViewController {
        let controller = PagedViewer.PagedController(collectionViewLayout: UICollectionViewFlowLayout())
        controller.model = model
        return controller
    }

    func updateUIViewController(_: UIViewControllerType, context _: Context) {}
}
