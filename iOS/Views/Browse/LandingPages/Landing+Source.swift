//
//  ContentSourceLandingPage.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-13.
//

import SwiftUI

struct SourceLandingPage: View {
    let sourceID: String
    @State var loadable = Loadable<JSCCS>.idle

    var body: some View {
        LoadableView(startSource,loadable) {
            LoadedSourceView(source: $0)
        }
    }
    
    func startSource() {
        loadable = .loading
        do {
            loadable = .loaded(try DSK.shared.getContentSource(id: sourceID))
        } catch {
            loadable = .failed(error)
        }
    }
    
    struct LoadedSourceView: View {
        let source: JSCCS
        var body: some View {
            Group {
                if hasPageLinkResolver {
                    ContentSourcePageView(source: source)
                        .navigationTitle("Home")
                } else {
                    ContentSourceDirectoryView(source: source, request: .init(page: 1))
                        .navigationTitle("\(source.name) Directory")
                        .navigationBarTitleDisplayMode(.inline)

                }
            }
        }
        var hasPageLinkResolver: Bool {
            UserDefaults.standard.bool(forKey: STTKeys.PageLinkResolver(source.id))
        }
    }
}
