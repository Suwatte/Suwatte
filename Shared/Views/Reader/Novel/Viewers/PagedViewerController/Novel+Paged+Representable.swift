//
//  Novel+Paged+Representable.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-30.
//

import Foundation
import SwiftUI

extension NovelReaderView {
    struct PagedViewer: UIViewControllerRepresentable {
        @EnvironmentObject var model: ViewModel

        func makeUIViewController(context _: Context) -> some UIViewController {
            let controller = Controller(collectionViewLayout: UICollectionViewLayout())
            controller.model = model
//            let controller = PagedController()
            return controller
        }

        func updateUIViewController(_: UIViewControllerType, context _: Context) {}
    }
}
