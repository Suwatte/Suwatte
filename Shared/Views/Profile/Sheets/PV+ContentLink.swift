//
//  PV+ContentLink.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-21.
//

import SwiftUI
//
// extension ProfileView.Sheets {
//    struct AddLinkedContentSheet: View {
//        var parent: StoredContent
//        var child: Loadable<StoredContent> = .idle
//        @StateObject var model = SearchView.ViewModel()
//        @State var selection: STTIdentifier? = nil
//        @ObservedObject var toastManager = ToastManager()
//        @Environment(\.presentationMode) var presentationMode
//        var body: some View {
//            ScrollView {
//                ForEach(model.results.filter { $0.source.id != parent.sourceId }, id: \.source.id) { _ in
////                    ExploreSectionsView.SoloSectionView(section: $0.section)
////                        .environmentObject($0.source)
////                        .environment(\.libraryIsSelecting, true)
////                        .environment(\.IdentifierSelection, $selection)
//                    Text("LINK")
//                }
//                Text("\(model.filteredResults + model.disabledSourceIds.count) Source(s) Filtered Out.")
//                    .font(.caption)
//                    .opacity(0.75)
//                    .padding(.vertical)
//            }
//            .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Manual Search")
//            .onAppear {
//                model.query = parent.title
//                model.load(model.query)
//            }
//            .onChange(of: selection) { newValue in
//                guard let newValue = newValue, let source = STTEngine.shared.getSource(with: newValue.sourceId) else {
//                    return
//                }
//                toastManager.setLoading()
//                let contentId = newValue.contentId
//
////                let identifier = STTEngine.identifier(newValue.sourceId, newValue.contentId)
//
//                // Save
//                source.getContent(id: contentId)
//                    .then { content in
//                        let stored = content.toStoredContent(withSource: source)
//                        DataManager.shared.storeContent(stored)
//                        let result = DataManager.shared.linkContent(parent: parent, child: stored)
//
//                        if !result {
//                            toastManager.setError(msg: "Content Already Linked")
//                        } else {
//                            toastManager.setComplete(title: "Linked")
//                        }
//
//                        presentationMode.wrappedValue.dismiss()
//                    }
//                    .catch { error in
//                        toastManager.setError(error: error)
//                    }
//
//                selection = nil
//            }
//            .toast(isPresenting: $toastManager.show) {
//                toastManager.toast
//            }
//        }
//    }
// }
