//
//  SearchView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import ASCollectionView
import RealmSwift
import SwiftUI

struct SearchView: View {
    typealias Highlight = DaisukeEngine.Structs.Highlight
    @State private var initial = true
    var initialQuery = ""
    @StateObject var model = ViewModel()

    @ObservedResults(LibraryEntry.self, where: { $0.isDeleted == false }) var library
    @ObservedResults(ReadLater.self, where: { $0.isDeleted == false }) var readLater

    @State var presentHistory = false
    @ObservedResults(UpdatedSearchHistory.self, where: { $0.sourceId == nil && $0.isDeleted == false }, sortDescriptor: SortDescriptor(keyPath: "date", ascending: false)) var history
    @AppStorage(STTKeys.TileStyle) var tileStyle = TileStyle.SEPARATED

    var body: some View {
        Group {
            if model.query.isEmpty {
                HISTORY_VIEW
            } else {
                RESULT_VIEW
                    .transition(.slide)
            }
        }
        .navigationTitle("Search All")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always))
        .onReceive(model.$query.debounce(for: .seconds(0.45), scheduler: DispatchQueue.main).dropFirst()) { val in
            if val.isEmpty {
                model.results.removeAll()
                return
            }
            model.makeRequests()
        }
        .onSubmit(of: .search) {
            let request: DSKCommon.SearchRequest = .init(query: model.query, page: 1)
            try? DataManager.shared.saveSearch(request, sourceId: nil, display: model.query)
        }
        .onAppear {
            if initialQuery.isEmpty || !initial { return }
            model.query = initialQuery
            model.makeRequests()
            initial.toggle()
        }
        .animation(.default, value: model.results)
        .animation(.default, value: model.query)
    }

    var disabledSourceIds: [String] {
        .init(rawValue: UserDefaults.standard.string(forKey: STTKeys.SourcesHiddenFromGlobalSearch) ?? "") ?? []
    }

    var sources: [AnyContentSource] {
        SourceManager.shared.sources.values.filter { !disabledSourceIds.contains($0.id) }
    }

    var RESULT_VIEW: some View {
        ASCollectionView(sections: RESULT_SECTIONS)
            .alwaysBounceVertical()
            .layout(scrollDirection: .vertical, interSectionSpacing: 7, layoutPerSection: { sectionID in

                if sectionID.contains("::FAILED") {
                    return ErrorLayout()
                }
                return LoadedLayout()
            })
            .animateOnDataRefresh(true)
            .shouldInvalidateLayoutOnStateChange(true)
    }

    func ErrorLayout() -> ASCollectionLayoutSection {
        return ASCollectionLayoutSection { _ in

            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .fractionalHeight(1)
            ))

            let itemsGroup = NSCollectionLayoutGroup.vertical(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(200)
                ),
                subitem: item, count: 1
            )

            let section = NSCollectionLayoutSection(group: itemsGroup)
            section.interGroupSpacing = 0
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 5)
            section.orthogonalScrollingBehavior = .none
            section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
            section.boundarySupplementaryItems = [.init(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(50)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)]
            return section
        }
    }

    func LoadedLayout() -> ASCollectionLayoutSection {
        return ASCollectionLayoutSection { _ in

            let iSeparated = tileStyle == .SEPARATED
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .fractionalHeight(1)
            ))

            let itemsGroup = NSCollectionLayoutGroup.vertical(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .absolute(150),
                    heightDimension: .absolute((150 * 1.5) + (iSeparated ? 50 : 0))
                ),
                subitem: item, count: 1
            )

            //            itemsGroup.interItemSpacing = .fixed(10)
            let section = NSCollectionLayoutSection(group: itemsGroup)
            section.interGroupSpacing = 7
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 5)
            section.orthogonalScrollingBehavior = .continuous
            section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
            section.boundarySupplementaryItems = [.init(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(50)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)]
            return section
        }
    }

    var RESULT_SECTIONS: [ASCollectionViewSection<String>] {
        model
            .results
            .sorted(by: { a, b in
                let aCount = a.value.value?.totalResultCount ?? a.value.value?.results.count ?? 0
                let bCount = b.value.value?.totalResultCount ?? b.value.value?.results.count ?? 0
                return bCount < aCount
            })
            .map { key, value in
                let source = model.sources.first(where: { $0.id == key })
                switch value {
                case let .loaded(data):

                    return ASCollectionViewSection(id: key, data: data.results) { cellData, _ in
                        let isInLibrary = inLibrary(cellData, key)
                        let isSavedForLater = savedForLater(cellData, key)
                        ZStack(alignment: .topTrailing) {
                            NavigationLink {
                                ProfileView(entry: cellData, sourceId: key)
                            } label: {
                                ExploreView.HighlightTile(entry: cellData, style: .NORMAL, sourceId: key)
                            }
                            .buttonStyle(NeutralButtonStyle())

                            if isInLibrary || isSavedForLater {
                                ColoredBadge(color: isInLibrary ? .accentColor : .yellow)
                            }
                        }
                    }
                    .sectionHeader {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(source?.name ?? "Source Not Found")
                                    .font(.headline.weight(.semibold))
                                if let count = data.totalResultCount {
                                    Text(count.description + " Results")
                                        .font(.subheadline.weight(.light))
                                }
                            }
                            Spacer()
                            if data.results.count < data.totalResultCount ?? 0, let source = source {
                                NavigationLink {
                                    EmptyView()
//                                ExploreView.SearchView(model: .init(request: .init(query: model.query), source: source))
                                } label: {
                                    Text("View More \(Image(systemName: "chevron.right"))")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical)
                    }
                case let .failed(error):
                    return ASCollectionViewSection(id: key + "::FAILED", data: ["FAILED"]) { _, _ in
                        ErrorView(error: error, action: {
                            model.loadForSource(id: key)
                        })
                    }
                    .sectionHeader {
                        HStack {
                            Text(source?.name ?? "Source Not Found")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }

                default:
                    return ASCollectionViewSection(id: key, data: DaisukeEngine.Structs.Highlight.placeholders()) { cellData, _ in
                        ExploreView.HighlightTile(entry: cellData, style: .NORMAL, sourceId: key)
                            .shimmering()
                            .redacted(reason: .placeholder)
                    }
                    .sectionHeader {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(source?.name ?? "Source Not Found")
                                    .font(.headline.weight(.semibold))
                                Text("...")
                                    .font(.subheadline.weight(.light))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                    }
                }
            }
    }

    var HISTORY_VIEW: some View {
        List {
            ForEach(history) { entry in
                Button {
                    didSelectHistory(entry)
                }
                label: {
                    HStack {
                        Text(entry.displayText)
                            .font(.headline)
                            .fontWeight(.light)
                        Spacer()
                        Text(entry.date.timeAgo())
                            .font(.subheadline.weight(.light))
                    }

                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: $history.remove(atOffsets:))
        }
    }

    func didSelectHistory(_ h: UpdatedSearchHistory) {
        model.query = h.displayText
    }

    func inLibrary(_ entry: Highlight, _ sourceId: String) -> Bool {
        library
            .contains(where: { $0.content?.sourceId == sourceId && $0.content?.contentId == entry.id })
    }

    func savedForLater(_ entry: Highlight, _ sourceId: String) -> Bool {
        readLater
            .contains(where: { $0.content?.sourceId == sourceId && $0.content?.contentId == entry.id })
    }
}

extension SearchView {
    final class ViewModel: ObservableObject {
        @Published var query = ""
        // Get Sources Filtered for Global Search
        @Published var results: [String: Loadable<DaisukeEngine.Structs.PagedResult>] = [:]

        private var disabledSourceIds: [String] {
            .init(rawValue: UserDefaults.standard.string(forKey: STTKeys.SourcesHiddenFromGlobalSearch) ?? "") ?? []
        }

        var sources: [StoredRunnerObject] {
            DataManager.shared.getSavedAndEnabledRunners().filter { !disabledSourceIds.contains($0.id) }
        }

        func makeRequests() {
            results.removeAll()
            let request = DaisukeEngine.Structs.SearchRequest(query: query)
            // Add All Sources To Loading
            sources.forEach { source in
                results[source.id] = .loading
                Task { @MainActor in
                    do {
                        let controller = try SourceManager.shared.getContentSource(id: source.id)
                        let data = try await controller.getSearchResults(request)
                        results[source.id] = .loaded(data)
                    } catch {
                        results[source.id] = .failed(error)
                    }
                }
            }
        }

        func loadForSource(id: String) {
            guard let source = sources.first(where: { $0.id == id }) else {
                return
            }
            Task { @MainActor in
                do {
                    let request = DSKCommon.SearchRequest(query: query)
                    let controller = try SourceManager.shared.getContentSource(id: source.id)
                    let data = try await controller.getSearchResults(request)
                    results[source.id] = .loaded(data)
                } catch {
                    results[source.id] = .failed(error)
                }
            }
        }
    }
}

extension Color {
    static var systemBackground: Color {
        .init(uiColor: .systemBackground)
    }
}