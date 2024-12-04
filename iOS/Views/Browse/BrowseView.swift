//
//  BrowseView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-27.
//

import RealmSwift
import SwiftUI

struct BrowseView: View {
    @StateObject private var model = PageLinkProviderModel(isForBrowsePage: true)
    @State var noListInstalled = false
    @State var presentOnboarding = false
    @State var isVisible = false
    @State var hasLoaded = false
    @State var hasCheckedForRunnerUpdates = false
    @State var runnersWithUpdates: [TaggedRunner] = []
    @State var presentUpdatesView = false
    @State var selectedSourceInfo: String?
    @State var presentSavedLists = false
    @State var showAddLocalSourceSheet = false

    var body: some View {
        SmartNavigationView {
            List {
                if noListInstalled {
                    NoListInstalledView
                        .transition(.opacity)
                }
                PendingSetupView()
                InstalledSourcesSection
                InstalledTrackersSection
                PageLinks
            }
            .headerProminence(.increased)
            .listStyle(.insetGrouped)
            .navigationBarTitle("Browse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    Menu {
                        Button {
                            presentSavedLists.toggle()
                        } label: {
                            Label("Lists", systemImage: "book.pages")
                        }
                        Button {
                            showAddLocalSourceSheet.toggle()
                        } label: {
                            Label("Install locale source", systemImage: "externaldrive.fill.badge.plus")
                        }
                    } label: {
                        Image(systemName: "shippingbox")
                    }
                }

                ToolbarItem {
                    NavigationLink {
                        SearchView()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentUpdatesView.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .opacity(runnersWithUpdates.isEmpty ? 0 : 1)
                }
            }
            .environmentObject(model)
            .refreshable {
                model.stopObserving()
                await model.observe()
            }
            .task {
                await checkForRunnerUpdates()
            }
            .fullScreenCover(item: $model.selectedRunnerRequiringSetup, onDismiss: model.reload, content: { runnerOBJ in
                SmartNavigationView {
                    LoadableRunnerView(runnerID: runnerOBJ.id) { runner in
                        DSKLoadableForm(runner: runner, context: .setup(closeOnSuccess: true))
                    }
                    .navigationTitle("\(runnerOBJ.name) Setup")
                    .closeButton()
                }
            })
            .fullScreenCover(item: $model.selectedRunnerRequiringAuth, onDismiss: model.reload, content: { runnerOBJ in
                SmartNavigationView {
                    LoadableRunnerView(runnerID: runnerOBJ.id) { runner in
                        List {
                            DSKAuthView(model: .init(runner: runner))
                        }
                    }
                    .navigationTitle("Sign In to \(runnerOBJ.name)")
                    .navigationBarTitleDisplayMode(.inline)
                    .closeButton(title: "Done")
                }
            })
            .sheet(item: $selectedSourceInfo, onDismiss: { selectedSourceInfo = nil }) { sourceInfo in
                SmartNavigationView {
                    SourceInfoGateway(runnerID: sourceInfo)
                        .navigationBarTitleDisplayMode(.inline)
                        .closeButton(title: "Close")
                }
            }
            .sheet(isPresented: $presentUpdatesView, content: {
                SmartNavigationView {
                    UpdateRunnersView(data: $runnersWithUpdates)
                }
            })
            .sheet(isPresented: $presentSavedLists) {
                SmartNavigationView {
                    RunnerListsView()
                        .closeButton(title: "Close")
                }
            }
            .animation(.default, value: model.links)
            .animation(.default, value: model.runners)
            .animation(.default, value: model.pending)
            .animation(.default, value: noListInstalled)
            .fileImporter(isPresented: $showAddLocalSourceSheet, allowedContentTypes: [.init(filenameExtension: "stt")!]) { result in

                guard let path = try? result.get() else {
                    ToastManager.shared.error("Task Failed")
                    return
                }

                if path.startAccessingSecurityScopedResource() {
                    Task {
                        do {
                            try await DSK.shared.importRunner(from: path)
                            await MainActor.run {
                                ToastManager.shared.info("Added!")
                            }
                        } catch {
                            await MainActor.run {
                                ToastManager.shared.error(error)
                            }
                        }
                        path.stopAccessingSecurityScopedResource()
                    }
                }
            }
        }
        .task {
            guard !hasLoaded else { return }
            await model.observe()
            checkLists()
            hasLoaded = true
        }
        .onDisappear {
            model.stopObserving()
        }
        .onReceive(StateManager.shared.browseUpdateRunnerPageLinks) { _ in
            hasLoaded = false
        }
        .fullScreenCover(isPresented: $presentOnboarding, onDismiss: checkLists) {
            OnboardingView()
        }
    }

    func checkLists() {
        Task {
            let lists = await RealmActor.shared().getRunnerLists()
            noListInstalled = lists.isEmpty
        }
    }

    func checkForRunnerUpdates() async {
        guard !hasCheckedForRunnerUpdates else { return }
        let data = await RealmActor.shared().getRunnerUpdates()
        await animate {
            runnersWithUpdates = data
        }
        hasCheckedForRunnerUpdates = true
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
                            VStack (alignment: .leading) {
                                Text(runner.name)
                                    .font(.headline)
                                Text("v" + runner.version.description)
                                    .font(.footnote)
                                    .fontWeight(.thin)
                                    .foregroundStyle(.gray)
                            }
                            Spacer()
                        }
                    }
                    .modifier(BrowseViewSourceModifier(selectedSourceInfo: $selectedSourceInfo, runner: runner))
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
                    .modifier(BrowseViewSourceModifier(selectedSourceInfo: $selectedSourceInfo, runner: runner))
                    .disabled(!runner.enabled)
                }
            } header: {
                Text("Trackers")
            }
        }
    }
}

extension BrowseView {
    struct SourceInfoGateway: View {
        let runnerID: String
        var body: some View {
            LoadableRunnerView(runnerID: runnerID) { runner in
                if let source = runner as? AnyContentSource {
                    ContentSourceInfoView(source: source)
                } else if let tracker = runner as? AnyContentTracker {
                    ContentTrackerInfoView(tracker: tracker)
                }
            }
        }
    }
}

struct BrowseViewSourceModifier: ViewModifier {
    @Binding var selectedSourceInfo: String?
    @State var runner: StoredRunnerObject

    func body(content: Content) -> some View {
        content
            .swipeActions {
                removeRunnerButton
                    .tint(.red)
            }
            .swipeActions(edge: .leading) {
                selectSourceInfoButton
                    .tint(.orange)
            }
            .contextMenu {
                selectSourceInfoButton
                removeRunnerButton
            }
    }

    var selectSourceInfoButton: some View {
        Button {
            selectedSourceInfo = runner.id
        } label: {
            Label("Info", systemImage: "info.circle")
        }
    }

    var removeRunnerButton: some View {
        Button(role: .destructive) {
            removeRunner()
        } label: {
            Label("Uninstall", systemImage: "trash")
        }
    }

    func removeRunner() {
        Task {
            await DSK.shared.removeRunner(runner.id)
            StateManager.shared.browseUpdateRunnerPageLinks.send()
            StateManager.shared.libraryUpdateRunnerPageLinks.send()
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
                        .modifier(BrowseViewSourceModifier(selectedSourceInfo: $selectedSourceInfo, runner: object))
                }
            }
        }

    }

    func PageLinksView(_ runner: StoredRunnerObject, _ links: [DSKCommon.PageLinkLabel]) -> some View {
        Section {
            ForEach(links, id: \.hashValue) { pageLink in
                NavigationLink {
                    PageLinkView(link: pageLink.link, title: pageLink.title, runnerID: runner.id)
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

extension BrowseView {
    var NoListInstalledView: some View {
        VStack(alignment: .center) {
            Text("New to Suwatte?")
                .font(.headline)
                .fontWeight(.semibold)
            Text("A quick guide on how to make the most of our app.")
                .font(.subheadline)
                .fontWeight(.light)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Button("Get Started") {
                presentOnboarding.toggle()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
    }
}

extension BrowseView {
    struct PendingSetupView: View {
        @EnvironmentObject private var model: PageLinkProviderModel
        var body: some View {
            Section {
                ForEach(model.runnersPendingSetup) { runner in
                    let state = model.pending[runner.id] ?? .setup
                    HStack(spacing: 15) {
                        STTThumbView(url: URL(string: runner.thumbnail))
                            .frame(width: 40, height: 40)
                            .cornerRadius(5)
                        VStack(alignment: .leading) {
                            Text(runner.name)
                            Text(state == .setup ? "\(runner.name) requires additional setup." : "Sign in to \(runner.name) to continue.")
                                .font(.caption.weight(.light).italic())
                        }
                        Spacer()
                        Button(state == .setup ? "Setup" : "Sign In") {
                            if state == .setup {
                                model.selectedRunnerRequiringSetup = runner
                            } else {
                                model.selectedRunnerRequiringAuth = runner
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

// MARK: ViewModel

final class PageLinkProviderModel: ObservableObject {
    private let isBrowsePageProvider: Bool
    @MainActor
    @Published
    var runners: [StoredRunnerObject] = []

    @MainActor
    @Published
    var links: [String: [DSKCommon.PageLinkLabel]] = [:]

    @MainActor
    @Published
    var pending: [String: LinkProviderPendingState] = [:]

    private var token: NotificationToken?

    @MainActor
    var runnersPendingSetup: [StoredRunnerObject] {
        runners.filter { pending.keys.contains($0.id) }
    }

    @MainActor
    @Published
    var selectedRunnerRequiringSetup: StoredRunnerObject?

    @MainActor
    @Published
    var selectedRunnerRequiringAuth: StoredRunnerObject?

    init(isForBrowsePage: Bool) {
        isBrowsePageProvider = isForBrowsePage
    }

    func observe() async {
        guard token == nil else { return }
        let actor = await RealmActor.shared()
        token = await actor.observeInstalledRunners { value in
            Task { @MainActor [weak self] in
                await animate { [weak self] in
                    self?.runners = value
                }
                await self?.getPageLinks()
            }
        }
    }

    func stopObserving() {
        token?.invalidate()
        token = nil
    }

    func getLinkProviders() async -> [AnyRunner] {
        let ids = await runners
            .filter { isBrowsePageProvider ? $0.isBrowsePageLinkProvider : $0.isLibraryPageLinkProvider }
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
                if let result = result as? AnyContentTracker, !result.intents.advancedTracker {
                    Logger.shared.warn("Tracker has Page Provider Intent but does not implement the AdvancedTracker Intent", result.id)
                    continue
                }
                out.append(result)
            }

            return out
        }

        return results
    }

    func getPageLinks() async {
        await MainActor.run {
            links.removeAll()
            pending.removeAll()
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
        if isBrowsePageProvider {
            guard runner.intents.browsePageLinkProvider else { return }
        } else {
            guard runner.intents.libraryPageLinkProvider else { return }
        }
        do {
            if runner.intents.requiresSetup {
                guard try await runner.isRunnerSetup().state else {
                    Task { @MainActor in
                        await animate { [weak self] in
                            self?.pending[runner.id] = .setup
                        }
                    }
                    return
                }
            }

            if let runner = runner as? AnyContentSource, runner.config?.requiresAuthenticationToAccessContent ?? false {
                guard runner.intents.authenticatable && runner.intents.authenticationMethod != .unknown else {
                    Logger.shared.warn("Runner has requested authentication to display content but has not implemented the required authentication methods.", runner.id)
                    return
                }
                guard let _ = try await runner.getAuthenticatedUser() else {
                    Task { @MainActor in
                        await animate { [weak self] in
                            self?.pending[runner.id] = .authentication
                        }
                    }
                    return
                }
            }
            let pageLinks = try await isBrowsePageProvider ? runner.getBrowsePageLinks() : runner.getLibraryPageLinks()
            guard !pageLinks.isEmpty else { return }

            Task { @MainActor in
                await animate { [weak self] in
                    self?.links.updateValue(pageLinks, forKey: runner.id)
                }
            }
        } catch {
            Logger.shared.error(error, runner.id)
        }
    }

    nonisolated
    func reload() {
        Task {
            stopObserving()
            await observe()
            await MainActor.run { [isBrowsePageProvider] in
                let manager = StateManager.shared
                isBrowsePageProvider ? manager.libraryUpdateRunnerPageLinks.send() : manager.browseUpdateRunnerPageLinks.send()
            }
        }
    }
}

enum LinkProviderPendingState {
    case authentication, setup
}

struct UpdateRunnersView: View {
    @Binding var data: [TaggedRunner]

    var body: some View {
        List {
            ForEach(data) { runner in
                HStack(spacing: 15) {
                    STTThumbView(url: URL(string: runner.thumbnail))
                        .frame(width: 40, height: 40)
                        .cornerRadius(5)
                    VStack(alignment: .leading) {
                        Text(runner.name)
                    }
                    Spacer()
                    Button("Update") {
                        update(runner: runner)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .closeButton()
        .navigationTitle("Runner Updates")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.default, value: data)
        .toast()
    }

    func update(runner: TaggedRunner) {
        Task {
            guard let url = URL(string: runner.listUrl) else {
                Logger.shared.error("Could not parse the Runner List", runner.id)
                ToastManager.shared.info("Could not parse the Runner List")
                return
            }
            do {
                try await DSK.shared.importRunner(from: url, with: runner.id)
                await animate {
                    data.removeAll(where: { $0.id == runner.id })
                }
            } catch {
                ToastManager.shared.error(error)
                Logger.shared.error(error, "Update~\(runner.id)")
            }
        }
    }
}
