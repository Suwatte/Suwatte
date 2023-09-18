//
//  DSKPageLInkView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-10.
//

import SwiftUI

struct PageLinkView: View {
    let link: DSKCommon.Linkable
    let title: String
    let runnerID: String
    var body: some View {
        LoadableRunnerView(runnerID: runnerID) { runner in
            Group {
                if link.isPageLink {
                    RunnerPageView(runner: runner, link: link.getPageLink())
                } else {
                    RunnerDirectoryView(runner: runner, request: link.getDirectoryRequest())
                }
            }
        }
        .navigationBarTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
