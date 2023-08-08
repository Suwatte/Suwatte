//
//  BrowseView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-27.
//

import RealmSwift
import SwiftUI

struct BrowseView: View {
    @StateObject private var model = ViewModel()
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
            .refreshable {
                await model.stopObserving()
                await model.observe()
            }
            .animation(.default, value: model.runners)
            .animation(.default, value: model.links)
        }
        .navigationViewStyle(.stack)

        .task {
            await model.observe()
        }
    }
}

// MARK: Sources

extension BrowseView {
    var sources: [StoredRunnerObject] {
        model.runners
            .filter { $0.environment == .source && !$0.isBrowsePageLinkProvider }
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
    var trackers: [StoredRunnerObject] {
        model.runners
            .filter { $0.environment == .tracker && !$0.isBrowsePageLinkProvider }
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
    var linkProviders: [StoredRunnerObject] {
        model
            .runners
            .filter { $0.isBrowsePageLinkProvider }
            .filter { model.links[$0.id] != nil }
    }

    var PageLinks: some View {
        Group {
            ForEach(linkProviders) { object in
                let id = object.id
                if let links = model.links[id] {
                    PageLinksView(object, links)
                }
            }
        }
    }

    func PageLinksView(_ runner: StoredRunnerObject, _ links: [DSKCommon.PageLinkLabel]) -> some View {
        Section {
            ForEach(links, id: \.hashValue) { pageLink in
                NavigationLink {
                    PageLinkView(pageLink: pageLink, runnerID: runner.id)
                } label: {
                    HStack {
                        STTThumbView(url: URL(string: pageLink.cover ?? runner.thumbnail))
                            .frame(width: 40, height: 40)
                            .cornerRadius(5)
                        Text(pageLink.title)
                        Spacer()
                    }
                }
            }
        } header: {
            Text(runner.name)
        }
    }
}

struct PageLinkView: View {
    let pageLink: DSKCommon.PageLinkLabel
    let runnerID: String
    @State var loadable: Loadable<AnyRunner> = .idle
    var body: some View {
        LoadableView(load, $loadable) { runner in
            Group {
                if pageLink.link.isPageLink {
                    RunnerPageView(runner: runner, link: pageLink.link.getPageLink())
                } else {
                    RunnerDirectoryView(runner: runner, request: pageLink.link.getDirectoryRequest())
                }
            }
        }
        .navigationBarTitle(pageLink.title)
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

// MARK: ViewModel
extension BrowseView {
    final actor ViewModel: ObservableObject {
        
        @MainActor
        @Published
        var runners: [StoredRunnerObject] = []
        
        @MainActor
        @Published
        var links :  [String: [DSKCommon.PageLinkLabel]] = [:]
        
        private var token: NotificationToken?
        
        
        func observe() async {
            guard token == nil else { return }
            let actor = await RealmActor()
            self.token = await actor.observeInstalledRunners { value in
                Task { @MainActor in
                    withAnimation {
                        self.runners = value
                    }
                    await self.getPageLinks()
                }
            }
        }
        
        func stopObserving() {
            token?.invalidate()
            token = nil
        }
        
        func getLinkProviders() async -> [AnyRunner] {
            let ids = await runners
                .filter(\.isBrowsePageLinkProvider)
                .map(\.id)
            
            let results = await withTaskGroup(of: AnyRunner?.self) { group in
                
                for id in ids {
                    group.addTask {
                        await DSK.shared.getRunner(id)
                    }
                }
                
                var out: [AnyRunner] = []
                for await result in group {
                    guard let result else { continue }
                    out.append(result)
                }
                
                return out
            }
            
            return results
        }
        
        func getPageLinks() async {
            await MainActor.run {
                links.removeAll()
            }
            let runners = await getLinkProviders()
            await withTaskGroup(of: Void.self) { group in
                for runner in runners {
                    group.addTask {
                        await self.load(for: runner)
                    }
                }
            }
        }
        
        func load(for runner: AnyRunner) async {
            guard runner.intents.browsePageLinkProvider else { return }
            do {
                let pageLinks = try await runner.getBrowsePageLinks()
                guard !pageLinks.isEmpty else { return }
                Task { @MainActor in
                    self.links.updateValue(pageLinks,forKey: runner.id)
                }
            } catch {
                Logger.shared.error(error, runner.id)
            }
        }
    }
}
