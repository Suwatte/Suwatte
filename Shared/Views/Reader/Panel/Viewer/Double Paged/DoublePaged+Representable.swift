//
//  DoublePaged+Representable.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-04.
//

import SwiftUI

struct DoublePagedViewer: UIViewControllerRepresentable {
    @EnvironmentObject var model: ReaderView.ViewModel

    func makeUIViewController(context _: Context) -> some UIViewController {
        let controller = Controller(collectionViewLayout: UICollectionViewFlowLayout())
        controller.model = model
        return controller
    }

    func updateUIViewController(_: UIViewControllerType, context _: Context) {}
}
