//
//  DRV+Preferences.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-11.
//

import SwiftUI

extension ContentSourceView {
    struct PreferencesView: View {
        var source: AnyContentSource
        @State var loadable = Loadable<[DSKCommon.PreferenceGroup]>.idle
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
                ContentSourceSettingsView(source: source, preferences: value)
            }
            .animation(.default, value: loadable)
        }

        func load() async {
            await MainActor.run(body: {
                loadable = .loading
            })
            do {
                let data = try await source.getSourcePreferences()
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

struct ContentSourceSettingsView: View {
    var source: AnyContentSource
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
        case .select: SelectionView(source: source, pref: pref)
        case .multiSelect: MultiSelectView(source: source, pref: pref)
        case .stepper: StepperView(source: source, pref: pref)
        case .textfield: TextFieldView(source: source, pref: pref)
        case .toggle: ToggleView(source: source, pref: pref)
        case .button: ButtoNView(source: source, pref: pref)
        }
    }
}

// MARK: Single Selector

extension ContentSourceSettingsView {
    struct SelectionView: View {
        var source: AnyContentSource
        var pref: DSKCommon.Preference
        @State var selection: String

        init(source: AnyContentSource, pref: DSKCommon.Preference) {
            self.source = source
            self.pref = pref
            let value = (pref.value.value as? String) ?? pref.options?.first?.value ?? ""
            _selection = State(initialValue: value)
        }

        var body: some View {
            Picker(pref.label, selection: $selection) {
                ForEach(pref.options ?? [], id: \.self) {
                    Text($0.label)
                        .tag($0.value)
                }
            }
            .onChange(of: selection) { _ in
                Task {
                    await source.updateSourcePreference(key: pref.key, value: selection)
                }
            }
        }
    }
}

// MARK: Toggle

extension ContentSourceSettingsView {
    struct ToggleView: View {
        var source: AnyContentSource
        var pref: DSKCommon.Preference
        @State var isOn: Bool

        init(source: AnyContentSource, pref: DSKCommon.Preference) {
            self.source = source
            self.pref = pref

            let value = (pref.value.value as? Bool) ?? false
            _isOn = State(initialValue: value)
        }

        var body: some View {
            Toggle(pref.label, isOn: $isOn)
                .onChange(of: isOn) { value in
                    Task {
                        await source.updateSourcePreference(key: pref.key, value: value)
                    }
                }
        }
    }
}

// MARK: TextField

extension ContentSourceSettingsView {
    struct TextFieldView: View {
        var source: AnyContentSource
        var pref: DSKCommon.Preference
        @State var text: String
        init(source: AnyContentSource, pref: DSKCommon.Preference) {
            self.source = source
            self.pref = pref
            let value = (pref.value.value as? String) ?? ""
            _text = State(initialValue: value)
        }

        var body: some View {
            TextField(pref.label, text: $text)
                .onSubmit {
                    Task {
                        await source.updateSourcePreference(key: pref.key, value: text)
                    }
                }
        }
    }
}

// MARK: Stepper

extension ContentSourceSettingsView {
    struct StepperView: View {
        var source: AnyContentSource
        var pref: DSKCommon.Preference
        @State var value: Int
        init(source: AnyContentSource, pref: DSKCommon.Preference) {
            self.source = source
            self.pref = pref
            let cValue = (pref.value.value as? Int) ?? pref.minStepper
            _value = State(initialValue: cValue)
        }

        var body: some View {
            Stepper(value: $value, in: pref.minStepper ... pref.maxStepper) {
                FieldLabel(primary: pref.label, secondary: value.description)
            }
            .onChange(of: value) { value in
                Task {
                    await source.updateSourcePreference(key: pref.key, value: value)
                }
            }
        }
    }
}

// MARK: MultiSelect

extension ContentSourceSettingsView {
    struct MultiSelectView: View {
        var source: AnyContentSource
        var pref: DSKCommon.Preference
        @State var selections: [String]
        init(source: AnyContentSource, pref: DSKCommon.Preference) {
            self.source = source
            self.pref = pref

            let value = (pref.value.value as? [String]) ?? []
            _selections = State(initialValue: value)
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
                Task {
                    await source.updateSourcePreference(key: pref.key, value: newValue)
                }
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

// MARK: Button

extension ContentSourceSettingsView {
    struct ButtoNView: View {
        var source: AnyContentSource
        var pref: DSKCommon.Preference
        init(source: AnyContentSource, pref: DSKCommon.Preference) {
            self.source = source
            self.pref = pref
        }

        var destructive: Bool {
            pref.isDestructive ?? false
        }

        var body: some View {
            Button(role: destructive ? .destructive : nil) {
                Task {
                    await source.updateSourcePreference(key: pref.key, value: "")
                }
            } label: {
                if let image = pref.systemImage {
                    Label(pref.label, systemImage: image)
                } else {
                    Text(pref.label)
                }
            }
        }
    }
}