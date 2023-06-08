//
//  HistoryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-01.
//

import RealmSwift
import SwiftUI

fileprivate let threeMonths = Calendar.current.date(
    byAdding: .month,
    value: -3,
    to: .now
)!
struct HistoryView: View {
    @StateObject var model = ViewModel()
    
    var body: some View {
        Group {
            if let markers = model.markers {
                List(markers) { marker in
                    Cell(marker: marker)
                        .listRowSeparator(.hidden)
                        .modifier(StyleModifier())
                        .modifier(DeleteModifier(id: marker.id))
                        .onTapGesture {
                            action(marker)
                        }
                }
                .transition(.opacity)
            } else {
                ProgressView()
                    .transition(.opacity)
            }
        }
        .modifier(InteractableContainer(selection: $model.csSelection))
        .listStyle(.plain)
        .navigationTitle("History")
        .animation(.default, value: model.markers)
        .task {
            model.observe()
        }
        .onDisappear(perform: model.disconnect)
    }
}

extension HistoryView {
    @MainActor
    final class ViewModel : ObservableObject {
        @Published var csSelection: HighlightIndentier?
        @Published var markers: Results<ProgressMarker>?
        
        private var notificationToken: NotificationToken?
        func observe() {
            let realm = try! Realm()
            let collection = realm
                .objects(ProgressMarker.self)
                .where({
                    $0.isDeleted == false &&
                    $0.currentChapter != nil &&
                    $0.dateRead != nil &&
                    $0.dateRead >= threeMonths &&
                    ($0.currentChapter.content != nil || $0.currentChapter.opds != nil)
                })
                .distinct(by: ["id"])
                .sorted(by: \.dateRead, ascending: false)
            notificationToken = collection
                .observe { _ in
                    self.markers = collection
                }
            
        }
        
        func disconnect() {
            notificationToken?.invalidate()
            notificationToken = nil
        }
    }
}

extension HistoryView {
    
    func action(_ marker: ProgressMarker) {
        if let content = marker.currentChapter?.content {
            model.csSelection = (content.sourceId, content.toHighlight())
        }
    }
    struct Cell: View {
        var marker: ProgressMarker
        var body: some View {
            Group {
                if let reference = marker.currentChapter {
                    if let content = reference.content {
                        ContentSourceCell(marker: marker, content: content, chapter: reference)
                    }
                }
            }
        }
    }
}

extension HistoryView {
    static var transition = AnyTransition.asymmetric(insertion: .slide, removal: .scale)

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
    
    
    struct DeleteModifier: ViewModifier {
        var id: String
        func body(content: Content) -> some View {
            content
                .swipeActions(allowsFullSwipe: true, content: {
                    Button(role: .destructive) {
                        handleRemoveMarker()
                    } label: {
                        Label("Remove", systemImage: "eye.slash")
                    }
                    .tint(.red)
                })
        }
        private func handleRemoveMarker() {
            DataManager.shared.removeFromHistory(id: id)
        }
    }
}


//
//extension HistoryView {
//    struct CellGateWay: View {
//        var marker: ProgressMarker
//        var chapter: ChapterReference {
//            marker.currentChapter! // Can Not Fail due to query in viewmodel
//        }
//        var body: some View {
//            Group {
//                if let content = chapter.content {
//                    ExternalContentTile(marker: marker, excerpt: content.toHighlight())
//                } else if chapter.isOPDS {
//                    OPDSContentTile(marker: marker)
//                } else if chapter.isLocal {
//                    LocalContentTile(marker: marker)
//                }
//            }
//            .modifier(DeleteModifier(marker: marker))
//        }
//    }
//}
