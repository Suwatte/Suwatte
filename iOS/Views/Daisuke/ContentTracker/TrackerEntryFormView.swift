//
//  TrackerEntryFormView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-08.
//

import AnyCodable
import SwiftUI
import UIKit

// MARK: - Core Form

struct TrackerEntryFormView: View {
    @StateObject var model: ViewModel
    var title: String
    var body: some View {
        LoadableView(model.load, model.loadable) { value in
            Form {
                ForEach(value.sections, id: \.hashValue) { section in
                    Section {
                        ForEach(section.children, id: \.key) {
                            ComponentBuilder(component: $0)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") { model.submit() }
                        .disabled(model.formUnchanged() || ToastManager.shared.loading)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .environmentObject(model)
        .navigationBarTitle(title)
    }
}

extension TrackerEntryFormView {
    final class ViewModel: ObservableObject {
        let id: String
        let tracker: JSCCT
        @Published var loadable: Loadable<DSKCommon.TrackForm> = .idle

        @Published private var form: [String: AnyCodable] = [:]

        init(tracker: JSCCT, id: String) {
            self.tracker = tracker
            self.id = id
        }

        func load() {
            Task {
                do {
                    let data = try await tracker.getEntryForm(id: id)
                    await MainActor.run {
                        withAnimation {
                            loadable = .loaded(data)
                        }
                    }
                } catch {
                    Logger.shared.error(error)
                    loadable = .failed(error)
                }
            }
        }

        func update(_ key: String, _ value: Codable) {
            withAnimation {
                form[key] = AnyCodable(value)
            }
        }

        func get(_ key: String) -> AnyCodable? {
            form[key]
        }

        func remove(_ key: String) {
            withAnimation {
                form[key] = AnyCodable(nil)
            }
        }

        func submit() {
            ToastManager.shared.loading = true
            Task {
                defer {
                    Task { @MainActor in
                        withAnimation {
                            ToastManager.shared.loading = false
                        }
                    }
                }
                do {
                    try await tracker.didSubmitEntryForm(id: id, form: form)
                    await MainActor.run {
                        withAnimation {
                            form = [:]
                            loadable = .idle
                        }
                    }
                    ToastManager.shared.info("Synced!")
                } catch {
                    Logger.shared.error(error)
                    await MainActor.run {
                        StateManager.shared.alert(title: "Failed to Sync", message: error.localizedDescription)
                    }
                }
            }
        }

        func formUnchanged() -> Bool {
            form.isEmpty
        }
    }
}

// MARK: Component Builder

extension TrackerEntryFormView {
    struct ComponentBuilder: View {
        let component: DSKCommon.TrackFormComponent

        var options: [DSKCommon.IOption] {
            component.options ?? []
        }

        var body: some View {
            Group {
                if component.faulty {
                    FieldLabel(primary: component.label, secondary: "Bad Configuration")
                } else {
                    switch component.type {
                    case .datepicker:
                        DatePickerComponent(component: component)
                    case .multipicker:
                        MultiSelectComponent(component: component)
                    case .picker:
                        Wrapper(component: component, defaultValue: options.first?.key ?? "") { binding in
                            Picker(component.label, selection: binding) {
                                ForEach(options, id: \.key) { option in
                                    Text(option.label)
                                        .tag(option.key)
                                }
                            }
                        }
                    case .stepper:
                        StepperComponent(component: component)
                    case .textfield:
                        Wrapper(component: component, defaultValue: "") { binding in
                            TextEditor(text: binding)
                        }
                    case .toggle:
                        Wrapper(component: component, defaultValue: false) { binding in
                            Toggle(component.label, isOn: binding)
                        }
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }
}

private typealias CBuilder = TrackerEntryFormView.ComponentBuilder

// MARK: DatePickerComponent

extension CBuilder {
    struct DatePickerComponent: View {
        let component: DSKCommon.TrackFormComponent
        private let formatter = ISO8601DateFormatter()

        @EnvironmentObject private var model: TrackerEntryFormView.ViewModel

        var value: Date? {
            let currentValue = component.currentValue?.value as? String
            let formValue = model.get(component.key)?.value

            if let formValue {
                if let formValue = formValue as? String {
                    let date = formatter.date(from: formValue)
                    return date
                } else if let formValue = formValue as? Date {
                    return formValue
                }
            } else if let currentValue {
                let date = formatter.date(from: currentValue)
                return date
            }

            return nil
        }

        var binding: Binding<Date> {
            .init(get: { value ?? .now }, set: { model.update(component.key, $0) })
        }

        var body: some View {
            Group {
                if component.faulty { // Improper Source Config
                    FieldLabel(primary: component.key, secondary: "Faulty Configuration")
                } else {
                    if value != nil {
                        HStack {
                            DatePicker(component.label, selection: binding, displayedComponents: .date)
                            if component.isRemovable {
                                Button("\(Image(systemName: "xmark"))") {
                                    model.remove(component.key)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.red)
                            }
                        }
                    } else {
                        HStack {
                            Text(component.label)
                            Spacer()
                            Button("\(Image(systemName: "plus"))") {
                                model.update(component.key, Date.now)
                            }
                            .buttonStyle(.plain)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.green)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - MultiSelectComponent

extension CBuilder {
    struct MultiSelectComponent: View {
        let component: DSKCommon.TrackFormComponent
        @State var selections = Set<DSKCommon.IOption>()
        @EnvironmentObject private var model: TrackerEntryFormView.ViewModel

        var body: some View {
            Wrapper(component: component, defaultValue: [String]()) { _ in
                NavigationLink {
                    MultiSelectionView(options: component.options ?? [], selection: $selections) { value in
                        Text(value.label)
                    }
                    .navigationTitle(component.label)
                    .onChange(of: selections) { newValue in
                        let out = newValue.map { $0.key }
                        model.update(component.key, out)
                    }
                } label: {
                    FieldLabel(primary: component.label, secondary: "\(selections.count) Selection(s)")
                }
            }
            .onAppear {
                let options = component.options ?? []
                let defaultValues = ((model.get(component.key)?.value ?? component.currentValue?.value) as? [String]) ?? []
                selections = Set(options.filter { defaultValues.contains($0.key) })
            }
        }
    }
}

// MARK: - Stepper Component

extension CBuilder {
    struct StepperComponent: View {
        @EnvironmentObject private var model: TrackerEntryFormView.ViewModel
        var component: DSKCommon.TrackFormComponent

        var value: Double? {
            let currentValue = model.get(component.key) ?? component.currentValue

            guard let currentValue else {
                return nil
            }

            if let value = currentValue.value as? Double {
                return value
            } else if let value = currentValue.value as? Int {
                return Double(value)
            }

            return nil
        }

        var step: Double {
            component.step ?? 1
        }

        var upperBound: Int {
            Int(component.upperBound ?? 9999)
        }

        var lowerBound: Int {
            Int(component.lowerBound ?? 0)
        }

        var body: some View {
            Group {
                if component.faulty { // Improper Source Config
                    FieldLabel(primary: component.label, secondary: "Faulty Configuration")
                } else {
                    if let value {
                        HStack {
                            PopulatedView(value)
                            RemoveButton
                        }
                    } else {
                        HStack {
                            Text(component.label)
                            Spacer()
                            Button("\(Image(systemName: "plus"))") {
                                model.update(component.key, 0.0)
                            }
                            .buttonStyle(.plain)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.green)
                        }
                    }
                }
            }
        }

        @ViewBuilder
        func PopulatedView(_ value: Double) -> some View {
            let label = "\(value.clean)\(UpperBoundString)"
            HStack {
                Text(component.label)
                Spacer()
                HStack {
                    Button {
                        presentAlert(value)
                    } label: {
                        Text(label)
                            .fontWeight(.light)
                            .foregroundColor(.primary.opacity(0.5))
                            .lineLimit(1)
                    }
                    StepperView(value: binding(value), step: step, range: lowerBound ... upperBound)
                }
            }
        }

        func binding(_ value: Double) -> Binding<Double> {
            .init {
                value
            } set: { newValue in
                model.update(component.key, newValue)
            }
        }

        func presentAlert(_ current: Double) {
            let alertController = UIAlertController(title: "Update \(component.label)", message: nil, preferredStyle: .alert)

            alertController.addTextField { textField in
                textField.placeholder = current.clean
                textField.keyboardType = component.isDecimalAllowed ? .decimalPad : .numberPad
            }

            let confirmAction = UIAlertAction(title: "Update", style: .default) { _ in
                guard let textField = alertController.textFields?.first, let text = textField.text else {
                    return
                }

                var value = Double(text) ?? current
                value = max(Double(lowerBound), value)
                value = min(Double(upperBound), value)
                model.update(component.key, value)
            }

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

            alertController.addAction(confirmAction)
            alertController.addAction(cancelAction)

            KEY_WINDOW?.rootViewController?.present(alertController, animated: true, completion: nil)
        }

        var UpperBoundString: String {
            let str = component.upperBound?.clean
            if let str {
                return " / \(str)"
            }
            return ""
        }

        var UnPopulatedView: some View {
            HStack {
                Text(component.label)
                Spacer()
                Button("\(Image(systemName: "plus"))") {
                    model.update(component.key, 0.0)
                }
                .buttonStyle(.plain)
                .font(.body.weight(.semibold))
                .foregroundColor(.green)
            }
        }

        @ViewBuilder
        var RemoveButton: some View {
            if component.isRemovable {
                Button("\(Image(systemName: "xmark"))") {
                    model.remove(component.key)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Generic Wrapper Component

extension CBuilder {
    struct Wrapper<T: Codable, C: View>: View {
        @EnvironmentObject private var model: TrackerEntryFormView.ViewModel

        let component: DSKCommon.TrackFormComponent
        let defaultValue: T
        let content: (_ binding: Binding<T>) -> C

        var current: T? {
            let val = model.get(component.key) ?? component.currentValue
            return val.flatMap { $0.value as? T }
        }

        init(component: DSKCommon.TrackFormComponent, defaultValue: T, @ViewBuilder _ content: @escaping (_ binding: Binding<T>) -> C) {
            self.component = component
            self.defaultValue = defaultValue
            self.content = content
        }

        var binding: Binding<T> {
            .init {
                current ?? defaultValue
            } set: { newValue in
                model.update(component.key, newValue)
            }
        }

        var body: some View {
            Group {
                if component.faulty { // Improper Source Config
                    FieldLabel(primary: component.key, secondary: "Faulty Configuration")
                } else {
                    if current != nil {
                        HStack {
                            content(binding)
                            if component.isRemovable {
                                Button("\(Image(systemName: "xmark"))") {
                                    model.remove(component.key)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.red)
                            }
                        }
                    } else {
                        HStack {
                            Text(component.label)
                            Spacer()
                            Button("\(Image(systemName: "plus"))") {
                                model.update(component.key, defaultValue)
                            }
                            .buttonStyle(.plain)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.green)
                        }
                    }
                }
            }
        }
    }
}
