//
//  DSKFormView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-31.
//

import AnyCodable
import SwiftUI

// MARK: LoadableForm

struct DSKLoadableForm: View {
    let runner: AnyRunner
    let context: DSKFormView.FormContext
    @State private var loadable: Loadable<DSKCommon.Form> = .idle

    var body: some View {
        LoadableView(runner.id, load, $loadable) { value in
            DSKFormView(model: .init(context: context, runner: runner), form: value)
        }
    }

    func load() async throws -> DSKCommon.Form {
        switch context {
        case let .tracker(id):
            guard let tracker = runner as? AnyContentTracker else {
                throw DSK.Errors.NamedError(name: "Invalid Runner", message: "A Tracker Must Request This")
            }
            return try await tracker.getEntryForm(id: id)
        case .preference:
            return try await runner.getPreferenceMenu()
        case .setup:
            return try await runner.getSetupMenu()
        }
    }
}

// MARK: FormView

struct DSKFormView: View {
    @StateObject var model: ViewModel
    let form: DSKCommon.Form
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        List {
            ForEach(form.sections, id: \.hashValue) { section in
                Section {
                    ForEach(section.children, id: \.id) { component in
                        ComponentBuilder(component: component)
                    }
                } header: {
                    if let header = section.header {
                        Text(header)
                    }
                } footer: {
                    if let footer = section.footer {
                        Text(footer)
                    }
                }
            }
        }
        .task {
            model.seed(with: form)
        }
        .environmentObject(model)
        .toolbar {
            if model.context.hasSubmitButton {
                Button("Submit") {
                    model.submit()
                }
                .disabled(!model.formHasChanged)
            }
        }
        .onChange(of: model.triggerClose) { newValue in
            guard newValue else { return }
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: FormContext

extension DSKFormView {
    enum FormContext {
        case tracker(id: String), preference, setup(closeOnSuccess: Bool = false)

        var hasSubmitButton: Bool {
            switch self {
            case .preference: return false
            default: return true
            }
        }
    }
}

// MARK: ViewModel

extension DSKFormView {
    final class ViewModel: ObservableObject {
        let context: FormContext
        let runner: AnyRunner

        @Published var triggerClose = false
        @Published var disabled: Set<String> = []
        @Published var form: [String: AnyCodable] = [:]
        @Published var formHasChanged = false
        init(context: FormContext, runner: AnyRunner) {
            self.context = context
            self.runner = runner
        }

        func didSet(_ value: Codable, for component: DSKCommon.FormComponent) {
            formHasChanged = true
            switch context {
            case .preference:
                triggerSettingUpdate(key: component.id, value: value)
            case .tracker, .setup:
                update(component.id, value)
            }
        }

        private func triggerSettingUpdate(key: String, value: Any) {
            Task {
                await runner.updatePreference(key: key, value: value)
            }
        }

        private func triggerTrackerFormSubmission(for id: String) {
            guard let tracker = runner as? AnyContentTracker else { return }

            ToastManager.shared.block { [form] in
                try await tracker
                    .didSubmitEntryForm(id: id, form: form)
                ToastManager.shared.info("Done.")
            }
        }

        private func triggerSetupMenuSubmission() {
            ToastManager.shared.block { [runner, form, context] in
                try await runner
                    .validateSetupForm(form: form)
                let state = try await runner.isRunnerSetup()
                guard state.state else { return }

                ToastManager.shared.info("\(runner.name) Setup!")
                if case let .setup(closeOnSuccess) = context, closeOnSuccess {
                    Task { @MainActor [weak self] in
                        self?.triggerClose = true
                    }
                }
            }
        }

        func update(_ key: String, _ value: Codable) {
            form[key] = AnyCodable(value)
        }

        func remove(_ key: String) {
            form.removeValue(forKey: key)
        }

        func submit() {
            switch context {
            case .preference: break
            case .setup:
                triggerSetupMenuSubmission()
            case let .tracker(id):
                triggerTrackerFormSubmission(for: id)
            }
        }

        func seed(with form: DSKCommon.Form) {
            let components = form.sections.flatMap { $0.children }
            for component in components {
                let key = component.id
                if let value = component.value {
                    self.form[key] = value
                }
            }
        }
    }
}

// MARK: ComponentBuilder

extension DSKFormView {
    struct ComponentBuilder: View {
        let component: DSKCommon.FormComponent
        @EnvironmentObject private var model: ViewModel
        var body: some View {
            HStack {
                if model.disabled.contains(component.id) {
                    AddButton
                    Text(component.title)
                } else {
                    if component.isOptional {
                        RemoveButton
                        Builder(component.type)
                    } else {
                        Builder(component.type)
                    }
                }
            }
        }

        var RemoveButton: some View {
            Button {
                model.disabled.insert(component.id)
                model.remove(component.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .tint(.red)
            }
        }

        var AddButton: some View {
            Button {
                model.disabled.remove(component.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .tint(.green)
            }
        }

        @ViewBuilder
        func Builder(_ type: DSKCommon.UIComponentType) -> some View {
            switch type {
            case .button: ButtonView(component: component)
            case .datepicker: DatePickerView(component: component)
            case .multipicker: MultiPickerView(component: component)
            case .picker: PickerView(component: component)
            case .stepper: StepperView(component: component)
            case .textfield: TextFieldView(component: component)
            case .toggle: ToggleView(component: component)
            }
        }
    }
}

// MARK: ButtonView

extension DSKFormView {
    struct ButtonView: View {
        let component: DSKCommon.FormComponent
        var body: some View {
            Button {} label: {
                if let image = component.systemImage {
                    Label(component.title, systemImage: image)
                } else {
                    Text(component.title)
                }
            }
        }
    }
}

// MARK: DatePicker

extension DSKFormView {
    struct DatePickerView: View {
        let component: DSKCommon.FormComponent
        @State private var value: Date = .now
        @State private var triggered = false
        @EnvironmentObject private var model: ViewModel
        private let formatter = ISO8601DateFormatter()

        init(component: DSKCommon.FormComponent) {
            self.component = component

            let currentValue = component.value?.value as? String
            if let currentValue, let date = formatter.date(from: currentValue) {
                _value = State(initialValue: date)
            }
        }

        var body: some View {
            DatePicker(component.title, selection: $value, displayedComponents: .date)
                .onChange(of: value, perform: didChange(_:))
                .animation(.default, value: value)
                .animation(.default, value: triggered)
        }

        func didChange(_ date: Date) {
            model.didSet(date, for: component)
        }
    }
}

// MARK: MultiPicker

extension DSKFormView {
    struct MultiPickerView: View {
        let component: DSKCommon.FormComponent
        @EnvironmentObject private var model: ViewModel
        @State private var selections: Set<DSKCommon.Option> = []

        init(component: DSKCommon.FormComponent) {
            self.component = component
            if let value = component.value?.value as? [String] {
                let chosen = Set(component.options?.filter { value.contains($0.id) } ?? [])
                _selections = State(initialValue: chosen)
            }
        }

        var body: some View {
            NavigationLink {
                MultiSelectionView(options: component.options ?? [], selection: $selections) { value in
                    Text(value.title)
                }
                .navigationTitle(component.title)
                .onChange(of: selections) { newValue in
                    let out = newValue.map { $0.id }
                    model.didSet(out, for: component)
                }
                .animation(.default, value: selections)
            } label: {
                FieldLabel(primary: component.title, secondary: "\(selections.count) Selection\(selections.count != 1 ? "s" : "")")
            }
        }
    }
}

// MARK: Picker

extension DSKFormView {
    struct PickerView: View {
        @EnvironmentObject private var model: ViewModel
        @State private var selection: String
        private let component: DSKCommon.FormComponent

        init(component: DSKCommon.FormComponent) {
            self.component = component
            let current = component.value?.value as? String ?? ""
            _selection = State(initialValue: current)
        }

        var body: some View {
            Picker(component.title, selection: $selection) {
                ForEach(component.options ?? []) { option in
                    Text(option.title)
                        .tag(option.id)
                }
            }
            .animation(.default, value: selection)
            .onChange(of: selection) { newValue in
                model.didSet(newValue, for: component)
            }
        }
    }
}

// MARK: StepperView

extension DSKFormView {
    struct StepperView: View {
        private let component: DSKCommon.FormComponent
        @EnvironmentObject private var model: ViewModel
        @State private var value: Double

        init(component: DSKCommon.FormComponent) {
            self.component = component
            let anyValue = component.value?.value
            if let anyValue {
                if let v = anyValue as? Double {
                    _value = State(initialValue: v)
                } else if let v = anyValue as? Int {
                    _value = State(initialValue: Double(v))
                } else {
                    _value = State(initialValue: component.lowerBound ?? 0)
                }
            } else {
                _value = State(initialValue: component.lowerBound ?? 0)
            }
        }

        var body: some View {
            HStack {
                Text(component.title)
                Spacer()
                HStack {
                    Button {
                        presentAlert(value)
                    } label: {
                        let label = "\(value.clean)\(UpperBoundString)"
                        Text(label)
                            .fontWeight(.light)
                            .foregroundColor(.primary.opacity(0.5))
                            .lineLimit(1)
                    }
                    UIStepperView(value: $value, step: step, range: lowerBound ... upperBound)
                }
            }
            .animation(.default, value: value)
            .onChange(of: value) { newValue in
                model.didSet(newValue, for: component)
            }
        }

        private func presentAlert(_ current: Double) {
            let alertController = UIAlertController(title: "Update \(component.title)", message: nil, preferredStyle: .alert)

            alertController.addTextField { textField in
                textField.placeholder = current.clean
                textField.keyboardType = component.allowsDecimal ? .decimalPad : .numberPad
            }

            let confirmAction = UIAlertAction(title: "Update", style: .default) { _ in
                guard let textField = alertController.textFields?.first, let text = textField.text else {
                    return
                }

                var prepped = Double(text) ?? current
                prepped = max(Double(lowerBound), prepped)
                prepped = min(Double(upperBound), prepped)
                value = prepped
            }

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

            alertController.addAction(confirmAction)
            alertController.addAction(cancelAction)

            let window = getKeyWindow()
            window?.rootViewController?.present(alertController, animated: true, completion: nil)
        }

        private var UpperBoundString: String {
            let str = component.upperBound?.clean
            if let str {
                return " / \(str)"
            }
            return ""
        }

        private var step: Double {
            component.step ?? 1
        }

        private var upperBound: Int {
            Int(component.upperBound ?? 9999)
        }

        private var lowerBound: Int {
            Int(component.lowerBound ?? 0)
        }
    }
}

// MARK: TextFieldView

extension DSKFormView {
    struct TextFieldView: View {
        private let component: DSKCommon.FormComponent
        @EnvironmentObject private var model: ViewModel
        @State private var text: String

        init(component: DSKCommon.FormComponent) {
            self.component = component
            _text = State(initialValue: component.value?.value as? String ?? "")
        }

        var body: some View {
            if component.multiline ?? false {
                TextEditor(text: $text)
                    .onChange(of: text, perform: { newValue in
                        model.didSet(newValue, for: component)
                    })

            } else {
                TextField(component.title, text: $text)
                    .onSubmit {
                        model.didSet(text, for: component)
                    }
            }
        }
    }
}

// MARK: ToggleView

extension DSKFormView {
    struct ToggleView: View {
        private let component: DSKCommon.FormComponent
        @EnvironmentObject private var model: ViewModel
        @State private var value: Bool

        init(component: DSKCommon.FormComponent) {
            self.component = component
            _value = State(initialValue: component.value?.value as? Bool ?? false)
        }

        var body: some View {
            Toggle(component.title, isOn: $value)
                .onChange(of: value) { _ in
                    model.didSet(value, for: component)
                }
        }
    }
}
