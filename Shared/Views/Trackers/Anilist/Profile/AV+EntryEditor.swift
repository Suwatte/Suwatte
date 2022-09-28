//
//  AV+EntryEditor.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-23.
//

import PartialSheet
import SwiftUI

extension AnilistView {
    struct EntryEditor: View {
        @State var entry: Anilist.Media.MediaListEntry
        var media: Anilist.Media
        @State var working = false
        
        var isManga: Bool {
            media.type == .manga
        }

        typealias Format = Anilist.MediaListOptions.ScoreFormat
        var scoreFormat: Format

        @State var presentScorePicker = false
        @State var presentProgressPicker = false
        @State var presentVolumePicker = false
        @State var presentReReadPicker = false

        var onListUpdated: (Anilist.Media.MediaListEntry) -> Void

        var maxProgress: Int {
            if isManga, let count = media.chapters {
                return count
            } else if !isManga, let count = media.episodes {
                return count
            }
            return 2500
        }

        var maxProgressString: String {
            if isManga, let count = media.chapters {
                return count.description
            } else if !isManga, let count = media.episodes {
                return count.description
            }

            return "-"
        }

        var maxVolume: Int {
            return media.volumes ?? 200
        }

        var maxVolumeString: String {
            media.volumes?.description ?? " - "
        }

        var maxScoreString: String {
            if let val = scoreFormat.getMax() {
                return " / \(val)"
            }
            return ""
        }

        var userScoreString: String {
            switch scoreFormat {
            case .POINT_10_DECIMAL, .POINT_10, .POINT_100: return entry.score.clean
            case .POINT_3: return Format.faces.get(index: Int(entry.score)) ?? "-"
            case .POINT_5: return Format.stars.get(index: Int(entry.score)) ?? "-"
            }
        }

        var body: some View {
            Form {
                // Score
                Section {
                    Button { presentScorePicker.toggle() } label: {
                        FieldLabel(primary: "Score", secondary: "\(userScoreString)\(maxScoreString)")
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .partialSheet(isPresented: $presentScorePicker, content: {
                        ScorePickerView(value: $entry.score, format: scoreFormat)

                    })
                }

                // Progress

                Section {
                    Button { presentProgressPicker.toggle() } label: {
                        FieldLabel(primary: "\(isManga ? "Chapter Progress" : "Episode Progress")", secondary: "\(entry.progress.description) / \(maxProgressString)")
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .partialSheet(isPresented: $presentProgressPicker, content: {
                        ProgressPicker(value: $entry.progress, maxProgress: maxProgress)
                    })

                    if isManga {
                        Button { presentVolumePicker.toggle() } label: {
                            FieldLabel(primary: "\(isManga ? "Volume Progress" : "Episode Progress")", secondary: "\(entry.progressVolumes?.description ?? "-") / \(maxVolumeString)")
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .partialSheet(isPresented: $presentVolumePicker, content: {
                            VolumePicker(value: Binding<Int>(get: {
                                entry.progressVolumes ?? 0
                            }, set: { val in
                                if val == 0 {
                                    entry.progressVolumes = nil
                                } else {
                                    entry.progressVolumes = val
                                }
                            }), maxVolume: maxVolume)
                        })
                    }
                }
                Section {
                    Button { presentReReadPicker.toggle() } label: {
                        FieldLabel(primary: "Total Re\(isManga ? "reads" : "watches")", secondary: entry.repeat.description)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .partialSheet(isPresented: $presentReReadPicker, content: {
                    ReReadPicker(value: $entry.repeat)
                })

                // Start & Finish Date

                Section {
                    if let fuzzy = entry.startedAt, let date = fuzzy.toDate() {
                        HStack {
                            DatePicker("Start Date",
                                       selection: Binding<Date>(get: { date }, set: { v in entry.startedAt = v.toFuzzyDate() }), displayedComponents: .date)
                            Button("\(Image(systemName: "xmark"))") {
                                entry.startedAt = .init()
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.red)
                        }
                    } else {
                        HStack {
                            Text("Start Date")
                            Spacer()
                            Button("\(Image(systemName: "plus"))") {
                                entry.startedAt = Date().toFuzzyDate()
                            }
                            .buttonStyle(.plain)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.green)
                        }
                    }

                    if let fuzzy = entry.completedAt, let date = fuzzy.toDate() {
                        HStack {
                            DatePicker("Completion Date",
                                       selection: Binding<Date>(get: { date },
                                                                set: { v in entry.completedAt = v.toFuzzyDate() }),
                                       displayedComponents: .date)
                            Button("\(Image(systemName: "xmark"))") {
                                entry.completedAt = .init()
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.red)
                        }
                    } else {
                        HStack {
                            Text("Completion Date")
                            Spacer()
                            Button("\(Image(systemName: "plus"))") {
                                entry.completedAt = Date().toFuzzyDate()
                            }
                            .buttonStyle(.plain)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.green)
                        }
                    }
                }

                // Rereads and Notes

                Section {
                    TextEditor(text: .init(get: {
                        entry.notes ?? ""
                    }, set: { val in
                        if val.isEmpty {
                            entry.notes = nil
                        } else {
                            entry.notes = val
                        }
                    }))
                } header: {
                    HStack {
                        Text("Notes")
                        Spacer()
                        Button("Clear") {
                            withAnimation {
                                entry.notes = nil
                            }
                        }
                        .opacity(entry.notes?.isEmpty ?? true ? 0 : 1)
                    }
                }

                // Custom Lists
                Section {
                    ForEach(entry.customLists ?? [], id: \.name) { list in
                        SelectionLabel(label: list.name, isSelected: list.enabled) {
                            let index = entry.customLists?.firstIndex(where: { $0.name == list.name })
                            if let index = index {
                                entry.customLists?[index].enabled.toggle()
                            }
                        }
                    }

                } header: {
                    Text("Custom Lists")
                }
                .buttonStyle(.plain)

                // Hide From Status && Is Private
                Section {
                    if isManga {
                        Toggle("Hide from status lists", isOn: $entry.hiddenFromStatusLists)
                    }
                    Toggle("Private", isOn: $entry.private)
                }
            }
            
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        working = true
                        Task { @MainActor in
                            ToastManager.shared.loading.toggle()
                            await update()
                            working = false
                            ToastManager.shared.loading.toggle()
                        }
                    }
                    .disabled(working)
                }
            }
            
            .animation(.default, value: entry)
            .toast()
        }
    }
}
extension AnilistView.EntryEditor {
    @MainActor
    func update() async {
        do {
            let response = try await Anilist.shared.updateMediaListEntry(entry: entry)
            self.entry = response
            self.onListUpdated(response)
            ToastManager.shared.display(.info("Synced!"))
        } catch {
            ToastManager.shared.display(.error(error))
        }
    }
}
extension AnilistView.EntryEditor {
    struct ReReadPicker: View {
        @Binding var value: Int

        var body: some View {
            Picker(selection: $value) {
                ForEach(0 ..< 100) {
                    Text($0.description)
                        .tag($0)
                }
            } label: {
                Text("ReRead")
            }
            .pickerStyle(.wheel)
        }
    }

    struct VolumePicker: View {
        @Binding var value: Int
        var maxVolume: Int?

        var slottedMax: Int {
            if let maxVolume = maxVolume {
                return maxVolume + 1
            }
            return 100
        }

        var body: some View {
            Picker(selection: $value) {
                ForEach(0 ..< slottedMax) {
                    Text($0.description)
                        .tag($0)
                }
            } label: {
                Text("Volume")
            }
            .pickerStyle(.wheel)
        }
    }

    struct ProgressPicker: View {
        @Binding var value: Int
        var maxProgress: Int?

        var slottedMax: Int {
            if let maxProgress = maxProgress {
                return maxProgress + 1
            }
            return 2000
        }

        var body: some View {
            Picker(selection: $value) {
                ForEach(1 ..< slottedMax) {
                    Text($0.description)
                        .tag($0)
                }
            } label: {
                Text("Progress")
            }
            .pickerStyle(.wheel)
        }
    }

    struct ScorePickerView: View {
        typealias Format = Anilist.MediaListOptions.ScoreFormat
        @Binding var value: Double
        var format: Format
        var body: some View {
            Picker(selection: $value) {
                switch format {
                case .POINT_10, .POINT_10_DECIMAL:
                    ForEach(0 ..< 11) {
                        Text($0.description)
                            .tag(Double($0))
                    }
                case .POINT_5:
                    ForEach(Format.stars) {
                        Text($0)
                            .tag(Format.stars.firstIndex(of: $0)!)
                    }
                case .POINT_3:
                    ForEach(Format.faces) {
                        Text($0)
                            .tag(Format.faces.firstIndex(of: $0)!)
                    }
                case .POINT_100:
                    ForEach(0 ..< 101) {
                        Text($0.description)
                            .tag(Double($0))
                    }
                }
            } label: {
                Text("Score Picker")
            }
            .pickerStyle(.wheel)
        }
    }
}
