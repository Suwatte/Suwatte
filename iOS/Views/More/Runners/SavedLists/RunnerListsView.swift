//
//  RunnerListsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-07.
//

import Alamofire
import FlagKit
import RealmSwift
import SwiftUI

struct RunnerListsView: View {
    @State var presentAlert = false
    @StateObject var model = ViewModel()
    @AppStorage(STTKeys.AppAccentColor) var color: Color = .sttDefault
    var body: some View {
        List {
            ForEach(model.savedLists) { list in
                NavigationLink {
                    RunnerListInfo(listURL: list.url)
                        .navigationTitle(list.listName ?? list.url)
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(list.listName ?? list.url)
                            .font(.headline)
                        if list.listName != nil {
                            Text(URL(string: list.url)?.sttBase?.absoluteString ?? list.url)
                                .font(.subheadline)
                                .fontWeight(.light)
                                .opacity(0.65)
                        }
                    }
                }
            }
//            .onDelete(perform: $runnerLists.remove(atOffsets:))
        }
        .navigationTitle("Saved Lists")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("\(Image(systemName: "plus"))") {
                    presentAlert.toggle()
                }
            }
        }
        .onChange(of: presentAlert) { newValue in
            if newValue {
                promptURL()
            }
        }
        .environmentObject(model)
        .task {
            await model.observe()
        }
        .onDisappear(perform: model.stopObserving)
    }
}

extension RunnerListsView {
    func handleSubmit(url: String) async {
        if url.isEmpty { return }
        do {
            try await DSK.shared.saveRunnerList(at: url)
            ToastManager.shared.display(.info("Saved List!"))

        } catch {
            ToastManager.shared.error(error)
            Logger.shared.error(error)

        }
        presentAlert = false
    }

    func promptURL() {
        let ac = UIAlertController(title: "Enter List URL", message: "Suwatte will parse valid URLS.", preferredStyle: .alert)
        ac.addTextField()
        let field = ac.textFields![0]
        field.autocorrectionType = .no
        field.keyboardType = .URL
        let submitAction = UIAlertAction(title: "Submit", style: .default) { [unowned ac] _ in
            let field = ac.textFields?.first
            guard let text = field?.text else {
                return
            }
            Task {
                await handleSubmit(url: text)
            }
        }
        ac.addAction(.init(title: "Cancel", style: .cancel, handler: { _ in
            presentAlert = false
        }))
        ac.addAction(submitAction)

        KEY_WINDOW?.rootViewController?.present(ac, animated: true)
    }
}

extension RunnerListsView {
    struct RunnerListInfo: View {
        var listURL: String
        @State var loadable: Loadable<RunnerList> = .idle
        @State var text: String = ""
        var body: some View {
            LoadableView(load, $loadable) { value in
                InternalListInfoView(list: value, listURL: listURL, text: $text)
            }
            .animation(.default, value: loadable)
            .refreshable {
                loadable = .idle
            }
            .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search...")
        }

        func load() async {
            loadable = .loading
            do {
                guard let url = URL(string: listURL) else {
                    throw DaisukeEngine.Errors.NamedError(name: "Parse Error", message: "Invalid URL")
                }
                let data = try await DSK.shared.getRunnerList(at: url)

                loadable = .loaded(data)
                let actor = await RealmActor()
                await actor.saveRunnerList(data, at: url)
            } catch {
                loadable = .failed(error)
            }
        }
    }

    struct InternalListInfoView: View {
        var list: RunnerList
        var listURL: String
        @Binding var text: String
        @AppStorage(STTKeys.HideNSFWRunners) var hideNSFW = true
        @State var presentFilterSheet = false
        @State var selectedLanguages = Set<String>()
        @State var langSearchText = ""
        var body: some View {
            List {
                let sources = filteredRunners.filter { $0.environment == .source }
                let trackers = filteredRunners.filter { $0.environment == .tracker }
                let plugins = filteredRunners.filter { $0.environment == .plugin }

                if !sources.isEmpty {
                    Section {
                        ForEach(sources) { source in
                            RunnerListInfo.RunnerListCell(listURL: listURL, list: list, runner: source)
                                .frame(height: 60)
                        }
                    } header: {
                        Text("Sources")
                    }
                }

                if !trackers.isEmpty {
                    Section {
                        ForEach(trackers) { tracker in
                            RunnerListInfo.RunnerListCell(listURL: listURL, list: list, runner: tracker)
                                .frame(height: 60)
                        }
                    } header: {
                        Text("Trackers")
                    }
                }

                if !plugins.isEmpty {
                    Section {
                        ForEach(plugins) { plugin in
                            RunnerListInfo.RunnerListCell(listURL: listURL, list: list, runner: plugin)
                                .frame(height: 60)
                        }
                    } header: {
                        Text("Plugins")
                    }
                }
            }
            .animation(.default, value: text)
            .toolbar(content: {
                ToolbarItem {
                    Button {
                        presentFilterSheet.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                }
            })
            .sheet(isPresented: $presentFilterSheet) {
                NavigationView {
                    List {
                        if !flaggedLanguages.isEmpty {
                            Section {
                                ForEach(flaggedLanguages.sorted(by: { Locale.current.localizedString(forIdentifier: $0) ?? "" < Locale.current.localizedString(forIdentifier: $1) ?? "" })) {
                                    Cell(lang: $0)
                                }
                            }
                        }

                        if !unflaggedLanguages.isEmpty {
                            Section {
                                ForEach(unflaggedLanguages.sorted(by: { Locale.current.localizedString(forIdentifier: $0) ?? "" < Locale.current.localizedString(forIdentifier: $1) ?? "" })) {
                                    Cell(lang: $0)
                                }
                            }
                        }
                    }
                    .animation(.default, value: langSearchText)
                    .animation(.default, value: selectedLanguages)
                    .navigationTitle("Languages")
                    .navigationBarTitleDisplayMode(.inline)
                    .searchable(text: $langSearchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
                    .closeButton()
                }
            }
        }

        func Cell(lang: String) -> some View {
            Button {
                if selectedLanguages.contains(lang) {
                    selectedLanguages.remove(lang)
                } else { selectedLanguages.insert(lang) }
            } label: {
                HStack {
                    LanguageCellView(language: lang)
                    Spacer()
                    Image(systemName: "checkmark")
                        .opacity(selectedLanguages.contains(lang) ? 1 : 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }

        var languages: [String] {
            let langs = Set(list.runners.flatMap { $0.supportedLanguages ?? [] })
            return Array(langs).filter { langSearchText.isEmpty || $0.lowercased().contains(langSearchText.lowercased()) }
        }

        var flaggedLanguages: [String] {
            languages.filter { Locale(identifier: $0).regionCode != nil }
        }

        var unflaggedLanguages: [String] {
            languages.filter { Locale(identifier: $0).regionCode == nil }
        }

        var filteredRunners: [Runner] {
            var base = list.runners

            if !text.isEmpty {
                let t = text.lowercased()
                base = base.filter { $0.name.lowercased().contains(t) }
            }

            if !selectedLanguages.isEmpty {
                base = base.filter { !Set($0.supportedLanguages ?? []).intersection(selectedLanguages).isEmpty }
            }

            return base.sorted(by: \.name, descending: false)
        }
    }
}

extension RunnerListsView.RunnerListInfo {
    struct RunnerListCell: View {
        @State var isLoading = false
        private let engine = DSK.shared
        var listURL: String
        var list: RunnerList
        var runner: Runner
        @EnvironmentObject var model: RunnerListsView.ViewModel
        var body: some View {
            let runnerState = getRunnerState(runner: runner)

            HStack {
                RunnerHeader(runner: runner)
                Spacer()
                Button {
                    Task { @MainActor in
                        isLoading = true
                        await saveExternalRunnerList()
                        isLoading = false
                    }
                } label: {
                    Group {
                        if !isLoading {
                            Text(runnerState.description)
                        } else {
                            ProgressView()
                        }
                    }
                    .font(.footnote.weight(.bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(runnerState.noInstall)
            }
        }

        enum RunnerState {
            case installed, outdated, sourceOutdated, notInstalled, appOutDated

            var description: String {
                switch self {
                case .installed:
                    return "REFRESH"
                case .outdated:
                    return "UPDATE"
                case .sourceOutdated:
                    return "OUTDATED"
                case .notInstalled:
                    return "GET"
                case .appOutDated:
                    return "UPDATE APP"
                }
            }

            var noInstall: Bool {
                self == .appOutDated || self == .sourceOutdated
            }
        }

        func saveExternalRunnerList() async {
            let base = URL(string: listURL)!

            do {
                try await DSK.shared.importRunner(from: base, with: runner.id)
                ToastManager.shared.info("\(runner.name) Saved!")
            } catch {
                ToastManager.shared.display(.error(error))
            }
        }

        func getRunnerState(runner: Runner) -> RunnerState {
            if let minVer = runner.minSupportedAppVersion, let appVersion = Bundle.main.releaseVersionNumber {
                let result = minVer.compare(appVersion)
                if ![ComparisonResult.orderedSame, .orderedAscending].contains(result) {
                    return .appOutDated
                }
            }
            guard let installed = model.savedRunners[runner.id] else {
                return .notInstalled
            }
            if installed.version > runner.version {
                return .sourceOutdated
            } else if installed.version == runner.version {
                return .installed
            } else {
                return .outdated
            }
        }

        func RunnerHeader(runner: Runner) -> some View {
            HStack(spacing: 7) {
                let url = runner.thumbnail.flatMap { URL(string: listURL)!.appendingPathComponent("assets").appendingPathComponent($0) }
                STTThumbView(url: url)
                    .frame(width: 44, height: 44, alignment: .center)
                    .cornerRadius(7)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .bottom, spacing: 3.5) {
                        Text(runner.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("v\(runner.version.description)")
                            .font(.subheadline)
                            .fontWeight(.thin)
                    }
                    HStack {
                        if runner.nsfw ?? false {
                            Text("18+")
                                .padding(.all, 2)
                                .background(Color.red.opacity(0.3))
                                .cornerRadius(5)
                        }
                    }
                    .font(.footnote.weight(.light))
                }
            }
            .frame(height: 60, alignment: .center)
        }
    }
}

extension RunnerListsView {
    struct AddSheet: View {
        @State var listURL: String = ""
        @Binding var presenting: Bool
        var body: some View {
            VStack(alignment: .leading, spacing: 15) {
                Text("Add List")
                    .font(.headline)
                HStack {
                    Image(systemName: "list.star")
                    TextField("List URL", text: $listURL)
                        .keyboardType(.URL)
                        .submitLabel(.go)
                        .autocapitalization(.none)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 15)
                .background(Color.fadedPrimary)
                .cornerRadius(7)
            }
            .toast()
            .onSubmit(of: .text) {
                Task {
                    await handleSubmit(url: listURL)
                }
            }
            .padding(.horizontal)
            .navigationTitle("Add New List")
        }

        func handleSubmit(url: String) async {
            if url.isEmpty { return }
            do {
                try await DSK.shared.saveRunnerList(at: url)
                DispatchQueue.main.async {
                    ToastManager.shared.display(.info("Saved Runner!"))
                    presenting.toggle()
                }

            } catch {
                DispatchQueue.main.async {
                    ToastManager.shared.display(.error(error))
                }
            }
        }
    }
}

extension URL {
    var runnersListURL: URL {
        appendingPathComponent("runners.json")
    }
}
