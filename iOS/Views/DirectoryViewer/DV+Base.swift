//
//  DV+Base.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-21.
//

import Foundation
import SwiftUI

extension DirectoryViewer {
    struct Coreview: View {
        @StateObject var model = DirectoryViewer.CoreModel()
        var body: some View {
            DirectoryViewer(model: .init())
                .environmentObject(model)
        }
    }
}
