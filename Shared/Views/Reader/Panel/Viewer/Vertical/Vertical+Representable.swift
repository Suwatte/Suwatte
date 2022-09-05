//
//  Vertical+Representable.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-12.
//

import Foundation

import SwiftUI

struct VerticalViewer: UIViewControllerRepresentable {
    @EnvironmentObject var model: ReaderView.ViewModel

    func makeUIViewController(context _: Context) -> some UIViewController {
        let controller = VerticalController(collectionViewLayout: UICollectionViewFlowLayout())
        controller.model = model
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_: UIViewControllerType, context _: Context) {}
}
