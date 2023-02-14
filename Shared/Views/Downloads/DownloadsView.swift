//
//  DownloadsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-08.
//

import ASCollectionView
import Kingfisher
import RealmSwift
import SwiftUI

struct DownloadsView: View {
    @State var presentQueue = false
    @ObservedResults(ICDMDownloadObject.self, where: { $0.status == .completed && $0.chapter != nil }, sortDescriptor: .init(keyPath: "dateAdded", ascending: false)) var downloads
    @State var text = ""
    @AppStorage(STTKeys.DownloadsSortLibrary) var sortOption: SortOption = .downloadCount
    @State var isDescending = true
    @AppStorage(STTKeys.GridItemsPerRow_P) var PortraitPerRow = 2
    @AppStorage(STTKeys.GridItemsPerRow_LS) var LSPerRow = 6
    @AppStorage(STTKeys.TileStyle) var style = TileStyle.COMPACT
    var body: some View {
        ASCollectionView(section: AS_SECTION)
            .layout(createCustomLayout: {
                DynamicGridLayout()
            }, configureCustomLayout: { layout in
                layout.invalidateLayout()
            })
            .alwaysBounceVertical()
            .animateOnDataRefresh(true)
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            presentQueue.toggle()
                        } label: {
                            Label("View Queue", systemImage: "list.bullet.indent")
                        }

                        Divider()
                        Picker("Sort Downloads", selection: $sortOption) {
                            ForEach(SortOption.allCases) {
                                Text($0.description)
                                    .tag($0)
                            }
                        }
                        .pickerStyle(.menu)
                        Button { isDescending.toggle() } label: {
                            Label("Order", systemImage: isDescending ? "chevron.down" : "chevron.up")
                        }

                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $presentQueue) {
                NavigationView {
                    DownloadsQueueView()
                        .closeButton()
                }
            }
            .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .animation(.default, value: text)
            .animation(.default, value: isDescending)
            .animation(.default, value: sortOption)
    }

    func getEntries() -> [StoredContent] {
        var data = DataManager
            .shared
            .getStoredContents(ids: downloads.map { $0.chapter!.ContentIdentifer })

        if !text.isEmpty {
            data = data.filter("ANY additionalTitles CONTAINS[cd] %@ OR title CONTAINS[cd] %@ OR summary CONTAINS[cd] %@", text, text, text)
        }

        let out = data
            .sorted(by: { lhs, rhs in
                switch sortOption {
                case .downloadCount: return downloadCount(for: lhs) < downloadCount(for: rhs)
                case .title: return lhs.title < rhs.title
                case .dateAdded: return STTHelpers.optionalCompare(firstVal: earliestDownload(for: lhs)?.dateAdded, secondVal: earliestDownload(for: rhs)?.dateAdded)
                }
            })

        if isDescending {
            return out.reversed()
        }

        return out
    }
}

// MARK: ASCollection

extension DownloadsView {
    var AS_SECTION: ASSection<Int> {
        let entries = getEntries()

        return ASSection(id: 0, data: entries) { data, _ in
            Cell(for: data)
        }
        .sectionHeader(content: {
            EmptyView()
        })
        .sectionFooter(content: {
            EmptyView()
        })
    }
}

extension DownloadsView {
    @ViewBuilder
    func Cell(for entry: StoredContent) -> some View {
        let downloadCount = downloadCount(for: entry)
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                ProfileView(entry: entry.toHighlight(), sourceId: entry.sourceId)
            } label: {
                DefaultTile(entry: entry.toHighlight(), sourceId: entry.sourceId)
            }
            .buttonStyle(NeutralButtonStyle())

            CapsuleBadge(text: downloadCount.description)
        }
    }

    func downloadCount(for entry: StoredContent) -> Int {
        downloads
            .filter { $0.chapter?.sourceId == entry.sourceId && $0.chapter?.contentId == entry.contentId }
            .count
    }

    func earliestDownload(for entry: StoredContent) -> ICDMDownloadObject? {
        downloads
            .last(where: { $0.chapter?.sourceId == entry.sourceId && $0.chapter?.contentId == entry.contentId })
    }
}

extension DownloadsView {
    enum SortOption: Int, CaseIterable, Identifiable {
        case title, downloadCount, dateAdded

        var description: String {
            switch self {
            case .downloadCount: return "Download Count"
            case .title: return "Content Title"
            case .dateAdded: return "Date Downloaded"
            }
        }

        var id: Int {
            return hashValue
        }
    }
}

struct CapsuleBadge: View {
    var text: String
    private let height: CGFloat = 17
    var body: some View {
        ZStack(alignment: .center) {
            Capsule()
                .foregroundColor(.systemBackground)
            ZStack(alignment: .center) {
                Capsule()
                    .foregroundColor(.accentColor)
                Text(text)
                    .font(.system(size: 10))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.all, 1)
            }
            .padding(.all, 3)
        }
        .frame(width: height * 2, height: height, alignment: .leading)
        .offset(x: 8, y: -8)
    }
}
