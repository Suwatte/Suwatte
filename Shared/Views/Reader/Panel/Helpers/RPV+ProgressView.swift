//
//  ProgressView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-31.
//

import SwiftUI

extension ReaderView {
    // MARK: Progress Object

    class ProgressObject: ObservableObject {
        @Published var progress: CGFloat = 0.0
        @Published var error: Error?
        @Published var action: (() -> Void)?

        private var oldProgress: CGFloat = 0 {
            didSet {
                if oldProgress >= 1 {
                    oldProgress = 0
                }
            }
        }

        func setProgress(_ val: CGFloat) {
            if val < oldProgress || val > 1 {
                return
            }
            withAnimation {
                progress = CGFloat(val)
            }

            oldProgress = val
        }

        func setError(_ error: Error, _ action: @escaping () -> Void) {
            withAnimation {
                self.error = error
                self.action = action
            }
        }
    }

    // MARK: Page Progress View

    struct PageProgressView: View {
        @ObservedObject var model: ProgressObject
        var color: Color = .accentColor
        var width: CGFloat = 5.5
        var body: some View {
            ZStack {
                if let error = model.error {
                    ErrorView(error: error, action: model.action!)
                } else {
                    Circle()
                        .trim(from: 0, to: model.progress)
                        .stroke(color, style: .init(lineWidth: width, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .background(Circle().stroke(color.opacity(0.2), style: .init(lineWidth: width, lineCap: .round)))
                        .frame(width: 40, height: 40, alignment: .center)
                }
            }
        }
    }
}
