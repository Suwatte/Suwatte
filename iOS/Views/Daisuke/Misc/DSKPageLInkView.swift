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
    @State private var loadable: Loadable<AnyRunner> = .idle
    var body: some View {
        LoadableView(load, $loadable) { runner in
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

    func load() async {
        loadable = .loading
        do {
            let runner = try await DSK.shared.getDSKRunner(runnerID)
            loadable = .loaded(runner)
        } catch {
            loadable = .failed(error)
        }
    }
}
