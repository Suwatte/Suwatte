//
//  FCS+Options.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-05.
//

import SwiftUI

struct FCS_Options: View {
    @EnvironmentObject var model: ProfileView.ViewModel
    let didChange: () -> Void
    @State private var providers: [DSKCommon.ChapterProvider] = []
    @State private var blacklisted: Set<String> = []
    @State private var triggeredInitial = false

    @State private var priorityCache: [String: ChapterProviderPriority] = [:]
    @State private var highPrioOrder: [String] = []
    private var HighPriority: [DSKCommon.ChapterProvider] {
        providers.filter { priorityCache[$0.id] == .always }
    }

    private var StandardProviders: [DSKCommon.ChapterProvider] {
        providers.filter { !blacklisted.contains($0.id) && priorityCache[$0.id] != .always }
    }

    private var HiddenProviders: [DSKCommon.ChapterProvider] {
        providers.filter { blacklisted.contains($0.id) }
    }

    var body: some View {
        SmartNavigationView {
            List {
                // High Priority Grouping
                HighPrioritySection
                // Standard
                ProvidersSection
                // Hidden
                HiddenSection
            }
            .environment(\.editMode, .constant(.active))
            .closeButton()
            .navigationBarTitle("Manage Providers")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.default, value: providers)
            .task {
                load()
            }
            .onChange(of: blacklisted) { value in
                guard triggeredInitial else { return }
                let content = model.getCurrentStatement().content
                STTHelpers.setBlackListedProviders(for: .init(contentId: content.highlight.id, sourceId: content.runnerID), values: Array(value))
                didChange()
            }
            .onChange(of: priorityCache) { value in
                guard triggeredInitial else { return }
                STTHelpers.setChapterPriorityMap(for: runnerID, value)
            }
            .animation(.default, value: providers)
            .animation(.default, value: blacklisted)
            .animation(.default, value: priorityCache)
        }
    }

    @ViewBuilder
    var HighPrioritySection: some View {
        let ps = HighPriority.sorted(by: { highPrioOrder.firstIndex(of: $0.id) ?? 99 < highPrioOrder.firstIndex(of: $1.id) ?? 99 })
        if !ps.isEmpty {
            Section {
                ForEach(ps) { provider in
                    ChapterProviderCell(provider: provider, sourceID: runnerID, blacklist: $blacklisted, priorityMap: $priorityCache)
                        .id(provider.id + "\(blacklisted.contains(provider.id))" + (priorityCache[provider.id] ?? .default).description)
                }
                .onMove { from, to in
                    var updated = ps
                    updated.move(fromOffsets: from, toOffset: to)
                    STTHelpers.setChapterHighPriorityOrder(for: model.currentChapterSection, list: updated.map(\.id))
                    highPrioOrder = STTHelpers.getChapterHighPriorityOrder(for: model.currentChapterSection)
                }
            } header: {
                Text("High Priority")
            } footer: {
                Text("This order will be used to pick between multiple high priority providers.")
            }
        }
    }

    var ProvidersSection: some View {
        Section {
            ForEach(StandardProviders.sorted(by: \.name.localizedLowercase, descending: false)) { provider in
                ChapterProviderCell(provider: provider, sourceID: runnerID, blacklist: $blacklisted, priorityMap: $priorityCache)
                    .id(provider.id + "\(blacklisted.contains(provider.id))" + (priorityCache[provider.id] ?? .default).description)
            }
        } header: {
            Text("Standard")
        }
    }

    var HiddenSection: some View {
        Section {
            ForEach(HiddenProviders.sorted(by: \.name.localizedLowercase, descending: false)) { provider in
                ChapterProviderCell(provider: provider, sourceID: runnerID, blacklist: $blacklisted, priorityMap: $priorityCache)
                    .id(provider.id + "\(blacklisted.contains(provider.id))" + (priorityCache[provider.id] ?? .default).description)
            }
        } header: {
            Text("Hidden")
        }
    }

    var runnerID: String {
        model.getCurrentStatement().content.runnerID
    }

    func getProviders() {
        let chapters = model.getCurrentStatement().originalList
        providers = chapters.compactMap(\.providers).flatMap { $0 }.distinct().sorted(by: \.name)
    }

    func getBlacklisted() {
        let content = model.getCurrentStatement().content
        blacklisted = Set(STTHelpers.getBlacklistedProviders(for: .init(contentId: content.highlight.id, sourceId: content.runnerID)))
    }

    func getPriorityDict() {
        priorityCache = STTHelpers.getChapterPriorityMap(for: runnerID)
        highPrioOrder = STTHelpers.getChapterHighPriorityOrder(for: model.currentChapterSection)
    }

    func load() {
        getProviders()
        getBlacklisted()
        getPriorityDict()
        triggeredInitial = true
    }
}

struct ChapterProviderCell: View {
    let provider: DSKCommon.ChapterProvider
    let sourceID: String
    @Binding var blacklist: Set<String>
    @Binding var priorityMap: [String: ChapterProviderPriority]

    private var priority: ChapterProviderPriority {
        priorityMap[provider.id] ?? .default
    }

    private var binding: Binding<ChapterProviderPriority> {
        .init(get: { priority }) { value in
            if value == .default {
                priorityMap[provider.id] = nil
            } else {
                priorityMap[provider.id] = value
            }
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(provider.name)
                if blacklist.contains(provider.id) {
                    Text("Hidden")
                        .bold()
                        .font(.caption)
                        .italic()
                } else {
                    Text("\(priority.description)")
                        .font(.caption)
                        .fontWeight(priority == .always ? .bold : .thin)
                        .foregroundColor(priority == .always ? .accentColor : .primary)
                        .italic()
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .contextMenu {
            Picker("Chapter Priority", selection: binding) {
                ForEach(ChapterProviderPriority.allCases, id: \.hashValue) { prio in
                    Text(prio.description)
                        .tag(prio)
                }
            }
            .pickerStyle(.menu)

            Divider()
            if blacklist.contains(provider.id) {
                Button("UnHide Chapers") {
                    blacklist.remove(provider.id)
                    binding.wrappedValue = .default
                }
            } else {
                Button("Hide Chapters") {
                    blacklist.insert(provider.id)
                    binding.wrappedValue = .avoid
                }
            }
        }
    }
}

enum ChapterProviderPriority: Int, CaseIterable, Codable {
    case avoid, low, `default`, high, always

    var description: String {
        switch self {
        case .avoid:
            return "Avoid"
        case .low:
            return "Low"
        case .default:
            return "Default"
        case .high:
            return "Elevated"
        case .always:
            return "Always Pick"
        }
    }
}

extension UserDefaults {
    func object<T: Codable>(_ type: T.Type, with key: String, usingDecoder decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard let data = value(forKey: key) as? Data else { return nil }
        return try? decoder.decode(type.self, from: data)
    }

    func set<T: Codable>(object: T, forKey key: String, usingEncoder encoder: JSONEncoder = JSONEncoder()) {
        do {
            let data = try encoder.encode(object)
            set(data, forKey: key)
            synchronize()
        } catch {
            Logger.shared.error(error)
        }
    }
}

extension STTHelpers {
    static func getChapterPriorityMap(for id: String) -> [String: ChapterProviderPriority] {
        UserDefaults.standard.object([String: ChapterProviderPriority].self, with: STTKeys.SourceChapterProviderPriority(id)) ?? [:]
    }

    static func setChapterPriorityMap(for id: String, _ map: [String: ChapterProviderPriority]) {
        UserDefaults.standard.set(object: map, forKey: STTKeys.SourceChapterProviderPriority(id))
    }

    static func setChapterHighPriorityOrder(for id: String, list: [String]) {
        UserDefaults.standard.set(object: list, forKey: STTKeys.TitleHighPriorityOrder(id))
    }

    static func getChapterHighPriorityOrder(for id: String) -> [String] {
        UserDefaults.standard.object([String].self, with: STTKeys.TitleHighPriorityOrder(id)) ?? []
    }
}
