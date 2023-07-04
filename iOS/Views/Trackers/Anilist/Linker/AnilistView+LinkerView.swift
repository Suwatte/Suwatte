//
//  AnilistView+LinkerView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-04.
//

import SwiftUI

extension AnilistView {
    struct LinkerView: View {
        final class SearchModel: ObservableObject {
            @Published var text: String = ""
        }

        var entry: DSKCommon.Content
        var sourceId: String
        @ObservedObject var model = SearchModel()
        @State var loadable = Loadable<Anilist.Page>.idle
        @Environment(\.presentationMode) var presentationMode
        var body: some View {
            List {
                Section {
                    HStack(alignment: .top) {
                        STTImageView(url: URL(string: entry.cover), identifier: .init(contentId: entry.contentId, sourceId: sourceId))
                            .frame(width: 100, height: 150, alignment: .center)
                            .cornerRadius(5)
                        VStack(alignment: .leading) {
                            Text(entry.title)
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(height: 160)
                } header: {
                    Text("Searching For")
                }

                LoadableView(actionTask, loadable) { data in
                    if data.media.isEmpty {
                        Text("No Results Found")
                    } else {
                        ForEach(data.media) { media in
                            Section {
                                LinkerCell(data: media)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        DataManager.shared.linkContentToTracker(id: ContentIdentifier(contentId: entry.contentId, sourceId: sourceId).id, al: media.id.description)
                                        presentationMode.wrappedValue.dismiss()
                                    }
                            } header: {
                                if media.id == data.media.first?.id {
                                    Text("Results")
                                }
                            }
                            .headerProminence(.increased)
                        }
                    }
                }
            }
            .searchable(text: $model.text, placement: .navigationBarDrawer(displayMode: .always))
            .onSubmit(of: .search) {
                actionTask()
            }
            .onAppear {
                model.text = entry.title
            }
            .onReceive(model.$text.debounce(for: .seconds(0.45), scheduler: DispatchQueue.main).dropFirst()) { val in
                if val.isEmpty { return }
                actionTask()
            }
            .navigationBarTitle("Link Content")
            .navigationBarTitleDisplayMode(.inline)
        }

        func actionTask() {
            Task {
                await load()
            }
        }

        @MainActor
        func load() async {
            loadable = .loading
            let request = Anilist.SearchRequest(type: .manga, search: model.text)
            do {
                let response = try await Anilist.shared.search(request)
                withAnimation {
                    loadable = .loaded(response)
                }
            } catch {
                loadable = .failed(error)
            }
        }
    }

    struct LinkerCell: View {
        var data: Anilist.SearchResult
        var body: some View {
            HStack(alignment: .top) {
                ZStack(alignment: .topLeading) {
                    BaseImageView(url: URL(string: data.coverImage.large))
                        .frame(width: 100, height: 150, alignment: .center)
                        .cornerRadius(5)
                        .shadow(radius: 2.5)

                    Image("anilist")
                        .resizable()
                        .frame(width: 27, height: 27, alignment: .center)
                        .cornerRadius(7)
                        .padding(.all, 3)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(data.title.userPreferred)
                        .font(.headline.weight(.semibold))
                    if let entry = data.mediaListEntry {
                        HStack {
                            Image(systemName: entry.status.systemImage)
                            Text(entry.status.description(for: data.type))
                        }
                        .foregroundColor(entry.status.color)
                        .font(.subheadline)
                    } else {
                        Text("Not Tracking")
                            .font(.subheadline.weight(.light))
                    }

//                    Spacer()
                }
                Spacer()
            }
            .padding(.vertical, 3)
        }
    }
}