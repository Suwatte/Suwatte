//
//  LCV+Grid.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-08.
//

import ASCollectionView
import Kingfisher
import RealmSwift
import SwiftUI

extension LocalContentView {
    struct Grid: View {
        var data: [LocalContentManager.Book]

        @ObservedResults(ChapterMarker.self, where: { $0.chapter.sourceId == STTHelpers.LOCAL_CONTENT_ID && $0.chapter != nil }) var localMarkers

        @Binding var isSelecting: Bool
        @State var selectedIndexes = Set<Int>()
        @State var selection: LocalContentManager.Book?
        @State private var isPotrait = KEY_WINDOW?.windowScene?.interfaceOrientation == .portrait

        @AppStorage(STTKeys.GridItemsPerRow_P) var PortraitPerRow = 2
        @AppStorage(STTKeys.GridItemsPerRow_LS) var LSPerRow = 6
        @AppStorage(STTKeys.LocalThumnailOnly) var showOnlyThumbs = false
        @AppStorage(STTKeys.LocalHideInfo) var showTitleOnly = false

        var itemsPerRow: Int {
            isPotrait ? PortraitPerRow : LSPerRow
        }

        var body: some View {
            ASCollectionView(editMode: isSelecting, section: AS_SECTION)
                .layout(createCustomLayout: {
                    GridLayout(itemsPerRow: itemsPerRow, showOnlyTitle: showTitleOnly, showOnlyThumbs: showOnlyThumbs)
                }, configureCustomLayout: { layout in
                    layout.itemsPerRow = itemsPerRow
                    layout.showOnlyTitle = showTitleOnly
                    layout.showOnlyThumbs = showOnlyThumbs
                })
                .alwaysBounceVertical()
                .animateOnDataRefresh(true)
                .onRotate { newOrientation in
                    if newOrientation.isFlat { return }
                    isPotrait = newOrientation.isPortrait
                }
                .animation(.default, value: isSelecting)
                .onChange(of: isSelecting, perform: { newValue in
                    if !newValue {
                        selectedIndexes.removeAll()
                    }
                })
                .fullScreenCover(item: $selection) { entry in
                    let chapter = LocalContentManager.shared.generateStored(for: entry)
                    ReaderGateWay(readingMode: entry.type == .comic ? .PAGED_COMIC : .NOVEL, chapterList: [chapter], openTo: chapter, title: entry.title)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        if isSelecting {
                            Button("Select") {}
                            Spacer()
                            Button("") {}
                        }
                    }
                }
        }
    }
}

extension LocalContentView.Grid {
    func isRead(id: Int64) -> Bool {
        localMarkers.contains(where: { $0.chapter?.contentId == String(id) })
    }
}

extension LocalContentView.Grid {
    var AS_SECTION: ASSection<Int> {
        ASSection(id: 0,
                  data: data,
                  selectionMode: .selectMultiple($selectedIndexes),
                  contextMenuProvider: contextMenuProvider) { cellData, cellContext in
            let isContentRead = isRead(id: cellData.id)
            ZStack(alignment: .topTrailing) {
                Button {
                    selection = cellData
                } label: {
                    LocalContentView.Tile(entry: cellData)
                }
                .buttonStyle(NeutralButtonStyle())
                .disabled(isSelecting)

                // Is Selected
                if isSelecting {
                    Image(systemName: "circle.fill")
                        .resizable()
                        .foregroundColor(cellContext.isSelected ? .accentColor : .black)
                        .clipShape(Circle())
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.white, lineWidth: 3).shadow(radius: 10))
                        .padding(.all, 5)
                        .transition(.scale)
                }

                if !isSelecting && !isContentRead {
                    ColoredBadge(color: .blue)
                }
            }
            .animation(.default, value: cellContext.isSelected)
        }
    }

    func contextMenuProvider(int _: Int, book: LocalContentManager.Book) -> UIContextMenuConfiguration?
    {
        let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil)
            { _ -> UIMenu? in

                var nonDestructiveActions = [UIAction]()
                var destructiveActions: [UIAction] = []

                // Share
                let shareAction = UIAction(title: "Share", image: .init(systemName: "square.and.arrow.up"))
                    { _ in
                        let av = UIActivityViewController(activityItems: [book.url], applicationActivities: nil)
                        KEY_WINDOW?.rootViewController?.present(av, animated: true)
                    }
                nonDestructiveActions.append(shareAction)

                // Rename Action
                let renameAction = UIAction(title: "Rename", image: .init(systemName: "pencil"))
                    { _ in
                        let alert = UIAlertController(title: "Rename File", message: nil, preferredStyle: .alert)
                        alert.addTextField { newTextField in
                            newTextField.placeholder = "Adventures of Mantton"
                            newTextField.text = book.fileName.replacingOccurrences(of: ".\(book.fileExt)", with: "")
                        }
                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in })
                        alert.addAction(UIAlertAction(title: "Done", style: .default) { _ in
                            if
                                let textFields = alert.textFields,
                                let tf = textFields.first,
                                let result = tf.text, !result.isEmpty
                            {
                                LocalContentManager.shared.handleRename(of: book, to: result)
                            }
                        })
                        KEY_WINDOW?.rootViewController?.present(alert, animated: true)
                    }

                nonDestructiveActions.append(renameAction)

                // Mark as Read
                let markAction = UIAction(title: "Mark as Read", image: .init(systemName: "eye"))
                    { _ in
                        // Mark
                    }
                nonDestructiveActions.append(markAction)

                // Delete
                let deleteAction = UIAction(title: "Delete", image: .init(systemName: "trash"), attributes: .destructive) { _ in
                    LocalContentManager.shared.handleDelete(of: book)
                }

                destructiveActions.append(deleteAction)

                let nonDestructiveMenu = UIMenu(title: "", options: .displayInline, children: nonDestructiveActions)

                let destructiveMenu = UIMenu(title: "", options: .displayInline, children: destructiveActions)

                return UIMenu(title: book.fileName, image: nil, identifier: nil, options: [], children: [nonDestructiveMenu, destructiveMenu])
            }
        return configuration
    }

    class GridLayout: UICollectionViewFlowLayout {
        var itemsPerRow: Int {
            didSet {
                invalidateLayout()
            }
        }

        var showOnlyThumbs: Bool {
            didSet {
                invalidateLayout()
            }
        }

        var showOnlyTitle: Bool {
            didSet {
                invalidateLayout()
            }
        }

        init(itemsPerRow: Int, showOnlyTitle: Bool, showOnlyThumbs: Bool) {
            self.itemsPerRow = itemsPerRow
            self.showOnlyTitle = showOnlyTitle
            self.showOnlyThumbs = showOnlyThumbs
            super.init()

            minimumInteritemSpacing = 6
            minimumLineSpacing = 6
            sectionInset = .init(top: 5, left: 20, bottom: 10, right: 20)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func prepare() {
            super.prepare()
            guard let collectionView = collectionView else { return }

            collectionView.allowsMultipleSelectionDuringEditing = true
            let itemSpacing = minimumInteritemSpacing * CGFloat(itemsPerRow - 1)
            let sectionInsets = sectionInset.left + sectionInset.right
            let insets = collectionView.safeAreaInsets
            let safeAreaInsets = insets.right + insets.left
            let total = itemSpacing + sectionInsets + safeAreaInsets
            let width = collectionView.bounds.width - total

            let itemWidth = (width / CGFloat(itemsPerRow)).rounded(.down)

            var itemHeight = itemWidth * 1.5
            if itemWidth >= 100, !showOnlyThumbs {
                if showOnlyTitle {
                    itemHeight += 44
                } else {
                    itemHeight += 90
                }
            }

            itemSize = CGSize(width: itemWidth, height: itemHeight)
        }
    }
}

extension LocalContentView {
    struct Tile: View {
        @EnvironmentObject var model: LocalContentManager
        var entry: LocalContentManager.Book
        @Environment(\.libraryIsSelecting) var libraryIsSelecting

        @AppStorage(STTKeys.LocalThumnailOnly) var showOnlyThumbs = false
        @AppStorage(STTKeys.LocalHideInfo) var showTitleOnly = false
        var subheading: String {
            var str = ""

            // Chapter Number & Page Count
            if let chapter = entry.chapter?.clean {
                str += "Chapter \(chapter)"
            }

            if entry.chapter != nil && entry.pageCount != nil {
                str += " • "
            }

            if let pageCount = entry.pageCount?.description {
                str += "\(pageCount) Pages"
            }
            str += "\n"

            // Year & File Size
            if let year = entry.year?.description {
                str += year
            }

            if entry.fileSize != nil && entry.year != nil {
                str += " • "
            }

            if let fileSize = entry.sizeToString() {
                str += fileSize
            }

            return str
        }

        var body: some View {
            GeometryReader { proxy in
                let imageWidth = proxy.size.width
                let imageHeight = imageWidth * 1.5
                VStack(alignment: .leading, spacing: 5) {
                    KFImage.source(entry.getImageSource())
                        .placeholder {
                            Image("stt_icon")
                                .resizable()
                                .scaledToFit()
                                .padding(.all)
                        }

                        .diskCacheExpiration(.expired)
                        .downsampling(size: .init(width: imageWidth * 2, height: imageHeight * 2))
                        .fade(duration: 0.30)
                        .resizable()
                        .frame(width: imageWidth, height: imageHeight)
                        .background(Color.fadedPrimary)
                        .cornerRadius(5)
                        .opacity(libraryIsSelecting ? 0.8 : 1)

                    if imageWidth >= 100, !showOnlyThumbs {
                        titleView
                            .frame(width: proxy.size.width, height: showTitleOnly ? 44 : 90, alignment: .topLeading)
                    }
                }
            }
        }

        var titleView: some View {
            VStack(alignment: .leading, spacing: 1.5) {
                Text(entry.title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !subheading.isEmpty && !showTitleOnly {
                    Text(subheading)
                        .font(.footnote)
                        .fontWeight(.thin)
                }
            }
        }
    }
}

struct ColoredBadge: View {
    var color: Color
    var bodySize: CGFloat = 17.0
    var internalSize: CGFloat = 12
    var offset: CGFloat = 8.0
    var body: some View {
        ZStack(alignment: .center) {
            Circle()
                .foregroundColor(.systemBackground)
            Circle()
                .foregroundColor(color)
                .frame(width: internalSize, height: internalSize)
        }
        .frame(width: bodySize, height: bodySize, alignment: .leading)
        .offset(x: offset, y: -offset)
        .transition(.scale)
    }
}
