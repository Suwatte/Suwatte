//
//  DRV+Preferences.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-11.
//

import SwiftUI

extension DaisukeContentSourceView {
    struct PreferencesView: View {
        @EnvironmentObject var source: DaisukeEngine.LocalContentSource
        @State var loadable = Loadable<[DSKCommon.PreferenceGroup]?>.idle
        var body: some View {
            LoadableView(loadable: loadable) {
                ProgressView()
                    .task {
                        await load()
                    }
            } _: {
                ProgressView()
            } _: { error in
                ErrorView(error: error) {
                    Task {
                        await load()
                    }
                }
            } _: { value in
                loadedView(value: value)
            }
            .animation(.default, value: loadable)
        }

        func load() async {
            await MainActor.run(body: {
                loadable = .loading
            })
            do {
                let data = try await source.getUserPreferences()
                await MainActor.run(body: {
                    loadable = .loaded(data)
                })

            } catch {
                await MainActor.run(body: {
                    loadable = .failed(error)
                })
            }
        }
    }
}

extension DaisukeContentSourceView.PreferencesView {
    @ViewBuilder
    func loadedView(value: [DSKCommon.PreferenceGroup]?) -> some View {
        if let preferences = value {
            ContentSourceSettingsView(preferences: preferences)
        } else {
            Text("Source has no settings :)")
                .font(.headline.weight(.light))
                .foregroundColor(.gray)
        }
    }
}

struct ContentSourceSettingsView: View {
    @EnvironmentObject var source: DSK.LocalContentSource
    var preferences: [DSKCommon.PreferenceGroup]
    var body: some View {
        Form {
            ForEach(preferences, id: \.self) { group in

                Section {
                    ForEach(group.children, id: \.key) { child in
                        TYPE_SWITCH(pref: child)
                    }
                } header: {
                    if let header = group.header {
                        Text(header)
                    }
                } footer: {
                    if let footer = group.footer {
                        Text(footer)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func TYPE_SWITCH(pref: DSKCommon.Preference) -> some View {
        switch pref.type {
        case .select: SelectionView(sourceId: source.id, pref: pref)
        case .multiSelect: MultiSelectView(sourceId: source.id, pref: pref)
        case .stepper: StepperView(sourceId: source.id, pref: pref)
        case .textfield: TextFieldView(sourceId: source.id, pref: pref)
        case .toggle: ToggleView(sourceId: source.id, pref: pref)
        }
    }
}

// MARK: Single Selector

extension ContentSourceSettingsView {
    struct SelectionView: View {
        var sourceId: String
        var pref: DSKCommon.Preference
        @State var selection: String

        init(sourceId: String, pref: DSKCommon.Preference) {
            self.sourceId = sourceId
            self.pref = pref
            let currentValue = DataManager.shared.getStoreValue(for: sourceId, key: pref.key)
            _selection = State(initialValue: currentValue ?? pref.defaultValue)
        }

        var body: some View {
            Picker(pref.label, selection: $selection) {
                ForEach(pref.options ?? [], id: \.self) {
                    Text($0.label)
                        .tag($0.value)
                }
            }
            .onChange(of: selection) { value in
                DataManager.shared.setStoreValue(for: sourceId, key: pref.key, value: value)
            }
        }
    }
}

// MARK: Toggle

extension ContentSourceSettingsView {
    struct ToggleView: View {
        var sourceId: String
        var pref: DSKCommon.Preference
        @State var isOn: Bool

        init(sourceId: String, pref: DSKCommon.Preference) {
            self.sourceId = sourceId
            self.pref = pref

            let currentValue = DataManager.shared.getStoreValue(for: sourceId, key: pref.key) ?? pref.defaultValue
            var active = false

            if currentValue == "1" || currentValue == "true" {
                active = true
            }

            _isOn = State(initialValue: active)
        }

        var body: some View {
            Toggle(pref.label, isOn: $isOn)
                .onChange(of: isOn) { value in
                    DataManager.shared.setStoreValue(for: sourceId, key: pref.key, value: value ? "true" : "false")
                }
        }
    }
}

// MARK: TextField

extension ContentSourceSettingsView {
    struct TextFieldView: View {
        var sourceId: String
        var pref: DSKCommon.Preference
        @State var text: String
        init(sourceId: String, pref: DSKCommon.Preference) {
            self.sourceId = sourceId
            self.pref = pref

            let currentValue = DataManager.shared.getStoreValue(for: sourceId, key: pref.key) ?? pref.defaultValue

            _text = State(initialValue: currentValue)
        }

        var body: some View {
            TextField(pref.label, text: $text)
                .onSubmit {
                    DataManager.shared.setStoreValue(for: sourceId, key: pref.key, value: text)
                }
        }
    }
}

// MARK: Stepper

extension ContentSourceSettingsView {
    struct StepperView: View {
        var sourceId: String
        var pref: DSKCommon.Preference
        @State var value: Int
        init(sourceId: String, pref: DSKCommon.Preference) {
            self.sourceId = sourceId
            self.pref = pref

            let currentValue = DataManager.shared.getStoreValue(for: sourceId, key: pref.key) ?? pref.defaultValue

            _value = State(initialValue: Int(currentValue) ?? 1)
        }

        var body: some View {
            Stepper(value: $value, in: pref.minStepper ... pref.maxStepper) {
                FieldLabel(primary: pref.label, secondary: value.description)
            }
            .onChange(of: value) { val in
                DataManager.shared.setStoreValue(for: sourceId, key: pref.key, value: String(val))
            }
        }
    }
}

// MARK: MultiSelect

extension ContentSourceSettingsView {
    struct MultiSelectView: View {
        var sourceId: String
        var pref: DSKCommon.Preference
        @State var selections: [String]
        init(sourceId: String, pref: DSKCommon.Preference) {
            self.sourceId = sourceId
            self.pref = pref

            let currentValue = DataManager.shared.getStoreValue(for: sourceId, key: pref.key) ?? pref.defaultValue

            let splitted = currentValue.components(separatedBy: ", ")

            _selections = State(initialValue: splitted)
        }

        var body: some View {
            NavigationLink {
                List {
                    ForEach(pref.options ?? [], id: \.self) { option in
                        let value = option.value
                        let isSelected = selections.contains(value)
                        SelectionLabel(label: option.label, isSelected: isSelected) {
                            toggleSelection(value: value)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .animation(.default, value: selections)
                .navigationTitle(pref.label)
            } label: {
                STTLabelView(title: pref.label, label: LABEL_V)
            }
            .onChange(of: selections) { newValue in
                let keyStoreValue = newValue.joined(separator: ", ")
                DataManager.shared.setStoreValue(for: sourceId, key: pref.key, value: keyStoreValue)
            }
        }

        func toggleSelection(value: String) {
            let count = selections.count
            if selections.contains(value) {
                if count - 1 >= pref.minSelect {
                    selections.removeAll(where: { $0 == value })
                }
            } else if count + 1 <= pref.maxSelect {
                selections.append(value)
            }
        }

        var LABEL_V: String {
            if selections.isEmpty {
                return "None"
            }
            if selections.count == 1 {
                return (pref.options ?? []).first(where: { $0.value == selections.first })?.label ?? "1 Selected"
            }

            return "\(selections.count) Selected"
        }
    }
}
