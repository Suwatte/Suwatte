//
//  AnilistView+MangaDirectory.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-23.
//

import ASCollectionView
import Kingfisher
import RealmSwift
import SwiftUI

extension AnilistView {
    struct DirectoryView: View {
        @StateObject var model: ViewModel
        @State var presentFiltersSheet = false
        @State var presentSortDialog = false
        @State var isDesc = true

        @AppStorage(STTKeys.TileStyle) var style = TileStyle.COMPACT
        @AppStorage(STTKeys.GridItemsPerRow_P) var PortraitPerRow = 2
        @AppStorage(STTKeys.GridItemsPerRow_LS) var LSPerRow = 6
        var itemsPerRow: Int {
            isPotrait ? PortraitPerRow : LSPerRow
        }

        @State private var isPotrait = KEY_WINDOW?.windowScene?.interfaceOrientation == .portrait

        func loadData() {
            Task {
                if model.response != .idle {
                    return
                }

                await model.make()
                await model.getGenres()
            }
        }

        var body: some View {
            LoadableView(loadable: model.response, {
                ProgressView()
                    .onAppear(perform: loadData)
            }, {
                ProgressView()
            }, { error in
                ErrorView(error: error, action: loadData)
            }, { value in
                LoadedView(values: value)
            })
            .sheet(isPresented: $presentFiltersSheet, onDismiss: {
                Task {
                    await model.make()
                }
            }) {
                FilterSheet()
            }
            .environmentObject(model)
            .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Browse \(model.request.type?.description ?? "")")
            .animation(.default, value: model.paginationStatus)
            .animation(.default, value: model.response)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("\(Image(systemName: "line.3.horizontal.decrease"))") {
                        presentFiltersSheet.toggle()
                    }
                }
            }
            .onReceive(model.$query.debounce(for: .seconds(0.45), scheduler: DispatchQueue.main).dropFirst()) { val in
                handleDidRecieveQuery(val)
            }
            .onChange(of: isDesc, perform: handleDidOrderChange(_:))
            .onRotate { newOrientation in
                if newOrientation.isFlat { return }
                isPotrait = newOrientation.isPortrait
            }
            .navigationBarTitleDisplayMode(.inline)
        }

        func LoadedView(values: [Anilist.SearchResult]) -> some View {
            ASCollectionView {
                ASCollectionViewSection(id: 1, data: values, onCellEvent: onCellEvent(_:)) { data, _ in
                    Tile(data: data)
                }
                .sectionHeader {
                    Header
                        .padding(.vertical)
                }
                .sectionFooter {
                    PaginationView
                }
            }
            .onPullToRefresh { endRefreshing in
                Task { @MainActor in
                    await model.make()
                    endRefreshing()
                }
            }
            .layout(createCustomLayout: {
                SuwatteDefaultGridLayout(itemsPerRow: itemsPerRow, style: style)
            }, configureCustomLayout: { layout in
                layout.itemsPerRow = itemsPerRow
                layout.itemStyle = style
                layout.headerReferenceSize = .init(width: layout.collectionView?.bounds.width ?? 0, height: 44)

                var height = 35
                switch model.paginationStatus {
                case .ERROR: height = 400
                default: break
                }
                layout.footerReferenceSize = .init(width: layout.collectionView?.bounds.width ?? 0, height: CGFloat(height))
            })
            .alwaysBounceVertical()
        }

        func onCellEvent(_ event: CellEvent<Anilist.SearchResult>) {
            switch event {
            case let .onAppear(item):
                if item != model.response.value?.last { return }
                Task { @MainActor in
                    await model.paginate()
                }
            default: break
            }
        }
    }
}

extension AnilistView.DirectoryView {
    func handleDidRecieveQuery(_ val: String) {
        if val.isEmpty {
            model.request.search = nil
            model.request.sort = [isDesc ? .POPULARITY_DESC : .POPULARITY]
        } else {
//            model.request = model.request.type == .anime ? .defaultAnimeRequest : .defaultMangaRequest
            model.request.search = val
            model.request.sort = [.SEARCH_MATCH]
        }

        Task {
            await model.make()
        }
    }

    func handleDidOrderChange(_ value: Bool) {
        guard let sort = model.request.sort.first, sort != .SEARCH_MATCH else {
            return
        }
        // Using rawvalue for my sanity
        var rawValue = sort.rawValue
        if rawValue.contains("_DESC") {
            // Remove
            rawValue = rawValue.replacingOccurrences(of: "_DESC", with: "")
        } else {
            rawValue.append(contentsOf: "_DESC")
        }

        let final = Anilist.MediaSort(rawValue: rawValue) ?? (value ? .POPULARITY_DESC : .POPULARITY)

        model.request.sort = [final]
        Task {
            await model.make()
        }
    }
}

extension AnilistView.DirectoryView {
    var Header: some View {
        HStack {
            Button { isDesc.toggle() } label: {
                Text("\(model.pageInformation.total) Results \(Image(systemName: isDesc ? "chevron.down" : "chevron.up"))")
            }

            Spacer()

            Button {
                presentSortDialog.toggle()
            } label: {
                HStack {
                    Text("Sort By: " + (model.request.sort.first?.description ?? "Default"))
                }
            }

            .buttonStyle(.plain)
            .multilineTextAlignment(.trailing)
        }
        .font(.subheadline.weight(.light))
        .foregroundColor(Color.primary.opacity(0.7))
        .padding(.horizontal)
        .confirmationDialog("Sort", isPresented: $presentSortDialog) {
            ForEach(SortOptions, id: \.rawValue) { sorter in
                Button(sorter.description) {
                    Task {
                        model.request.sort = [sorter]
                        await model.make()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    var SortOptions: [Anilist.MediaSort] {
        Anilist.MediaSort.getList(desc: isDesc, type: model.request.type ?? .anime)
    }

    @ViewBuilder
    var PaginationView: some View {
        switch model.paginationStatus {
        case .IDLE: EmptyView()
        case .LOADING: ProgressView()
        case .END: Text("End Reached")
            .font(.caption)
            .fontWeight(.semibold)
            .multilineTextAlignment(.center)
            .foregroundColor(.gray)
        case let .ERROR(error):
            ErrorView(error: error, action: {
                Task {
                    await model.paginate()
                }
            })
        }
    }

    struct Tile: View {
        var data: Anilist.SearchResult
        @State var listStatus: Anilist.MediaListStatus?
        @AppStorage(STTKeys.TileStyle) var tileStyle = TileStyle.SEPARATED
        @State var isPresenting = false
        @State var firstCall = false
        var body: some View {
            GeometryReader { reader in
                ZStack(alignment: .topTrailing) {
                    switch tileStyle {
                    case .COMPACT:
                        CompactStyle(reader: reader)
                    case .SEPARATED:
                        SeparatedStyle(reader: reader)
                    }

                    if let listStatus = listStatus {
                        ListEntry(listStatus)
                    }
                }
            }
            .onAppear(perform: {
                if !firstCall {
                    listStatus = data.mediaListEntry?.status
                    firstCall = true
                }

            })
            .onTapGesture {
                isPresenting.toggle()
            }
            .background {
                NavigationLink(destination: AnilistView.ProfileView(entry: data, onStatusUpdated: { _, status in
                    listStatus = status
                }), isActive: $isPresenting, label: { EmptyView() })
            }
        }

        var ImageV: some View {
            BaseImageView(url: URL(string: data.coverImage.extraLarge))
        }

        func CompactStyle(reader: GeometryProxy) -> some View {
            ZStack {
                ImageV
                LinearGradient(gradient: Gradient(colors: [.clear, Color(red: 15 / 255, green: 15 / 255, blue: 15 / 255)]), startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading) {
                    Spacer()
                    Text(data.title.userPreferred)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .foregroundColor(Color.white)
                        .shadow(radius: 2)
                        .multilineTextAlignment(.leading)
                        .padding(.all, 5)
                }
                .frame(maxWidth: reader.size.width, alignment: .leading)
            }
            .cornerRadius(10)
        }

        func SeparatedStyle(reader: GeometryProxy) -> some View {
            VStack(alignment: .leading, spacing: 5) {
                ImageV
                    .frame(height: reader.size.width * 1.5)
                    .cornerRadius(7)

                Text(data.title.userPreferred)
                    .font(.subheadline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }

        func ListEntry(_ status: Anilist.MediaListStatus) -> some View {
            ColoredBadge(color: status.color)
        }
    }
}

extension AnilistView.DirectoryView {
    //    @MainActor
    final class ViewModel: ObservableObject {
        @Published var request: Anilist.SearchRequest
        @Published var pageInformation: Anilist.Page.PageInfo
        @Published var response: Loadable<[Anilist.SearchResult]> = .idle
        @Published var paginationStatus: ExploreView.SearchView.ViewModel.PaginationStatus = .IDLE
        @Published var query: String = ""
        @Published var genres = Loadable<Anilist.GenreResponse.NestedVal>.idle

        init(_ request: Anilist.SearchRequest) {
            self.request = request
            pageInformation = .defualtPage
        }

        @MainActor
        func make() async {
            response = .loading
            request.page = 1

            do {
                let result = try await Anilist.shared.search(request)
                response = .loaded(result.media)
                pageInformation = result.pageInfo
            } catch {
                response = .failed(error)
            }
        }

        @MainActor
        func paginate() async {
            paginationStatus = .LOADING

            if !pageInformation.hasNextPage {
                paginationStatus = .END
                return
            }
            request.page += 1
            do {
                let results = try await Anilist.shared.search(request)
                var current = response.value ?? []
                current.append(contentsOf: results.media)
                pageInformation = results.pageInfo
                response = .loaded(current)
                paginationStatus = .IDLE
            } catch {
                paginationStatus = .ERROR(error: error)
                request.page -= 1
            }
        }

        func reset() {
            paginationStatus = .IDLE
            response = .idle

            pageInformation = .defualtPage

            if let type = request.type {
                request = .init(type: type)
            }
        }
    }
}

extension AnilistView.DirectoryView.ViewModel {
    @MainActor
    func getGenres() async {
        genres = .loading
        do {
            let data = try await Anilist.shared.getTags()
            genres = .loaded(data)
        } catch {
            genres = .failed(error)
        }
    }
}
