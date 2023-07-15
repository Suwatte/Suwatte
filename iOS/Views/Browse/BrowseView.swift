//
//  BrowseView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-27.
//

import RealmSwift
import SwiftUI

struct BrowseView: View {
    @ObservedResults(StoredRunnerObject.self, where: { $0.isDeleted == false }, sortDescriptor: .init(keyPath: "name")) var runners
    @State var pageLinks: [String: [DSKCommon.PageLink]] = [:]
    @State var triggeredLoad = false
    var body: some View {
        NavigationView {
            List {
                InstalledSourcesSection
                InstalledTrackersSection
                PageLinks
            }
            .listStyle(.insetGrouped)
            .navigationBarTitle("Browse")
            .toolbar {
                ToolbarItem {
                    NavigationLink {
                        SearchView()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }

                }
            }
        }
        .navigationViewStyle(.stack)

        .task {
            guard !triggeredLoad else { return }
            triggeredLoad = true
            loadPageLinks()
        }
    }


    var SortedRunners: Results<StoredRunnerObject> {
        runners
            .sorted(by: [SortDescriptor(keyPath: "enabled", ascending: true),
                         SortDescriptor(keyPath: "name", ascending: true)])
    }
}

// MARK: Sources
extension BrowseView {
    var sources: Results<StoredRunnerObject> {
        SortedRunners
            .where { $0.environment == .source }
            .where { !$0.isBrowsePageLinkProvider }
    }

    @ViewBuilder
    var InstalledSourcesSection: some View {
        if !sources.isEmpty {
            Section {
                ForEach(sources) { runner in
                    NavigationLink {
                        SourceLandingPage(sourceID: runner.id)
                            .navigationBarTitle(runner.name)
                    } label: {
                        HStack(spacing: 15) {
                            STTThumbView(url: URL(string: runner.thumbnail))
                                .frame(width: 40, height: 40)
                                .cornerRadius(5)
                            Text(runner.name)
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(!runner.enabled)
                }
            } header: {
                Text("Sources")
            }
        }
    }
}

// MARK: Trackers
extension BrowseView {
    var trackers: Results<StoredRunnerObject> {
        SortedRunners
            .where { $0.environment == .tracker }
            .where { !$0.isBrowsePageLinkProvider }
    }
    
    @ViewBuilder
    var InstalledTrackersSection: some View {
        if !trackers.isEmpty {
            Section {
                ForEach(trackers) { runner in
                    NavigationLink {
                        TrackerLandingPage(trackerID: runner.id)
                            .navigationBarTitle(runner.name)

                    } label: {
                        HStack(spacing: 15) {
                            STTThumbView(url: URL(string: runner.thumbnail))
                                .frame(width: 40, height: 40)
                                .cornerRadius(5)
                            Text(runner.name)
                            Spacer()
                        }
                    }
                    .disabled(!runner.enabled)
                }
            } header: {
                Text("Trackers")
            }
        }
    }
}

// MARK: - Page Links
extension BrowseView {
    var linkProviders: Results<StoredRunnerObject> {
        SortedRunners
            .where { $0.isBrowsePageLinkProvider }
    }
    var PageLinks: some View {
        Group {
            ForEach(linkProviders) { object in
                let id = object.id
                if let links = pageLinks[id], let runner = DSK.shared.getRunner(id) {
                    PageLinksView(runner, links)
                }
            }
        }
    }
    
    
    func PageLinksView(_ runner: JSCRunner, _ links: [DSKCommon.PageLink]) -> some View {
        Section {
            ForEach(links, id: \.hashValue) { pageLink in
                NavigationLink {
                    PageLinkView(pageLink: pageLink, runner: runner)
                } label: {
                    HStack {
                        STTThumbView(url: URL(string: pageLink.thumbnail ?? "") ?? runner.thumbnailURL)
                            .frame(width: 40, height: 40)
                            .cornerRadius(5)
                        Text(pageLink.label)
                        Spacer()
                    }
                }
            }
        } header: {
            Text(runner.name)
        }
    }
}


// MARK: - Load Page Links
extension BrowseView {
    func loadPageLinks() {
        // Get Links
        let runnerIDs = runners
            .where { $0.isBrowsePageLinkProvider }
            .map(\.id)
        // Remove All
        withAnimation {
            pageLinks.removeAll()
        }
        // Load all links, log errors
        Task {
            await withTaskGroup(of: Void.self, body: { group in
                for id in runnerIDs {
                    group.addTask {
                        do {
                            let runner = try DSK.shared.getJSCRunner(id)
                            guard runner.intents.browsePageLinkProvider else { return }
                            let links = try await runner.getBrowsePageLinks()
                            guard !links.isEmpty else { return }
                            Task { @MainActor in
                                withAnimation {
                                    pageLinks.updateValue(links , forKey: runner.id)
                                }
                            }
                        } catch {
                            Logger.shared.error(error, id)
                        }
                    }
                }
            })
        }
    }
}


struct PageLinkView: View {
    let pageLink: DSKCommon.PageLink
    let runner: JSCRunner
    var body: some View {
        Group {
            if pageLink.link.isPageLink {
                RunnerPageView(runner: runner, pageKey: pageLink.link.getPageKey())
                    .navigationBarTitle(pageLink.label)
            } else {
                RunnerDirectoryView(runner: runner, request: pageLink.link.getDirectoryRequest())
                    .navigationBarTitle(pageLink.label)
            }
        }
    }
}
