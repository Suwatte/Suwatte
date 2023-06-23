//
//  VerticalPaged+Representable.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-12-22.
//

import Foundation
import SwiftUI
import UIKit

struct VerticalPager: UIViewControllerRepresentable {
    @EnvironmentObject var model: ReaderView.ViewModel
    func makeUIViewController(context _: Context) -> some UIViewController {
        let controller = Controller(collectionViewLayout: .init())
        controller.model = model
        return controller
    }

    func updateUIViewController(_: UIViewControllerType, context _: Context) {}
}
