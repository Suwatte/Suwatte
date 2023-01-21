//
//  HistoryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-01.
//

import RealmSwift
import SwiftUI

struct HistoryView: View {
    @StateObject var model = ViewModel()
    
    var body: some View {
        List {
            ForEach(model.markers) { marker in
                CellGateWay(marker: marker)
                    .listRowSeparator(.hidden)
                    .id(marker.id)
            }
            .animation(.default, value: model.markers)
        }
        .listStyle(.plain)
        .navigationTitle("History")
        .modifier(InteractableContainer(selection: $model.selection))
        .fullScreenCover(item: $model.selectedBook, onDismiss: model.observe) { entry in
            let chapter = LocalContentManager.shared.generateStored(for: entry)
            ReaderGateWay(readingMode: entry.type == .comic ? .PAGED_COMIC : .NOVEL, chapterList: [chapter], openTo: chapter, title: entry.title)
                .onAppear {
                    model.removeObserver()
                }
        }
        .fullScreenCover(item: $model.selectedOPDSContent, onDismiss: model.observe) { entry in
            let chapter = DataManager.shared.getLatestStoredChapter(entry.sourceId, entry.contentId)
            Group {
                if let chapter {
                    ReaderGateWay(readingMode:  .PAGED_COMIC, chapterList: [chapter], openTo: chapter, title: entry.chapterName)
                } else {
                    NavigationView {
                        Text("This Content Could not be found")
                            .closeButton()
                    }
                }
            }
            .onAppear {
                model.removeObserver()
            }
        }
        .environmentObject(model)
        .onDisappear(perform: model.removeObserver)
        .task {
            if model.token == nil {
                model.observe()
            }
        }
    }
}

extension HistoryView {
    struct StyleModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.primary.opacity(0.05))
                .cornerRadius(10)
                .contentShape(Rectangle())
        }
    }

    struct ProgressIndicator: View {
        var progress: CGFloat = 0.0
        @AppStorage(STTKeys.AppAccentColor) var color: Color = .sttDefault
        var width: CGFloat = 5.5

        var body: some View {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: .init(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .background(Circle().stroke(color.opacity(0.2), style: .init(lineWidth: width, lineCap: .round)))
                .frame(width: 40, height: 40, alignment: .center)
        }
    }
}

extension HistoryView {
    struct CellGateWay: View {
        var marker: HistoryObject
        var body: some View {
            Group {
                switch marker.sourceId {
                    case STTHelpers.OPDS_CONTENT_ID:
                        OPDSContentTile(marker: marker)
                    case STTHelpers.LOCAL_CONTENT_ID:
                        LocalContentTile(marker: marker)
                    default:
                        ExternalContentTile(marker: marker)
                }
            }
            .modifier(DeleteModifier(marker: marker))

        }
    }
}
