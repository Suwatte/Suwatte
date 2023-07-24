//
//  DV+CollectionView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-21.
//

import ASCollectionView
import NukeUI
import SwiftUI
import UIKit

extension DirectoryViewer {
    struct CoreCollectionView: View {
        let directory: Folder
        @Binding var isEditing: Bool
        @AppStorage(STTKeys.GridItemsPerRow_P) var PortraitPerRow = 2
        @AppStorage(STTKeys.GridItemsPerRow_LS) var LSPerRow = 6
        @AppStorage(STTKeys.LocalThumnailOnly) var showOnlyThumbs = false
        @AppStorage(STTKeys.LocalHideInfo) var showTitleOnly = false
        @EnvironmentObject var coreModel: DirectoryViewer.CoreModel
        @State var selectedIndexes = Set<Int>()
        @State var triggerValue = 0
        var body: some View {
            ASCollectionView(editMode: isEditing) {
                // Folder Section
                ASCollectionViewSection(id: 0, data: directory.folders.sorted(by: \.name, descending: false), contentBuilder: Builder)
                    .cacheCells()

                // Files Section
                ASCollectionViewSection(id: 1, data: directory.files, selectionMode: .selectMultiple($selectedIndexes), contentBuilder: Builder)
            }
            .animateOnDataRefresh(true)
            .alwaysBounceVertical(true)
            .layout { section in
                LayoutBuilder(section)
            }
            .shouldInvalidateLayoutOnStateChange(true)
            .ignoresSafeArea(.keyboard, edges: .all)
            .animation(.default, value: directory)
            .animation(.default, value: directory.files)
            .onChange(of: PortraitPerRow, perform: trigger)
            .onChange(of: LSPerRow, perform: trigger)
            .onChange(of: showOnlyThumbs, perform: trigger)
            .onChange(of: showTitleOnly, perform: trigger)
        }

        func trigger(_: AnyHashable) {
            triggerValue += 1 // Make View Update
        }

        func Builder(_ file: File, _ context: ASCellContext) -> some View {
            CellWrapper(file: file, context: context)
                .environmentObject(coreModel)
                .environment(\.libraryIsSelecting, isEditing)
        }

        func Builder(_ folder: Folder.SubFolder, _: ASCellContext) -> some View {
            Color.primary.opacity(0.10)
                .cornerRadius(7)
                .overlay {
                    NavigationLink {
                        DirectoryViewer(model: .init(path: folder.url), title: folder.name)
                            .environmentObject(coreModel)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "folder")
                                .foregroundColor(.primary.opacity(0.75))
                            Text(folder.name)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.footnote)
                        .padding(.all)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
        }
    }
}

extension DirectoryViewer {
    struct CellWrapper: View {
        @State var file: File
        let context: ASCellContext
        @EnvironmentObject var coreModel: DirectoryViewer.CoreModel
        @Environment(\.libraryIsSelecting) var isEditing
        var body: some View {
            ZStack(alignment: .topTrailing) {
                Button {
                    if file.isOnDevice {
                        coreModel.didTapFile(file)
                    } else {
                        coreModel.downloadAndRun(file) {
                            file = $0
                        }
                    }

                } label: {
                    Cell(file: file, context: context, isDownloading: isDownloading)
                }
                .buttonStyle(NeutralButtonStyle())
                .disabled(isEditing)

                Image(systemName: "circle.fill")
                    .resizable()
                    .foregroundColor(context.isSelected ? .accentColor : .black)
                    .clipShape(Circle())
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(Color.white, lineWidth: 3).shadow(radius: 10))
                    .padding(.all, 5)
                    .opacity(isEditing ? 1 : 0)
            }
            .animation(.default, value: isEditing)
            .animation(.default, value: context.isSelected)
        }

        var isDownloading: Bool {
            coreModel.currentDownloadFileId == file.id
        }
    }

    struct Cell: View {
        var file: File
        let context: ASCellContext
        var isDownloading: Bool
        @AppStorage(STTKeys.LocalThumnailOnly) var showOnlyThumbs = false
        @AppStorage(STTKeys.LocalHideInfo) var showTitleOnly = false
        @Environment(\.libraryIsSelecting) var isEditing

        var body: some View {
            GeometryReader { proxy in
                let imageWidth = proxy.size.width
                let imageHeight = imageWidth * 1.5
                let size = CGSize(width: imageWidth, height: imageHeight)
                VStack(alignment: .leading, spacing: 5) {
                    BaseImageView(request: request(size: size))
                        .frame(width: imageWidth, height: imageHeight)
                        .cornerRadius(7)
                        .overlay {
                            Color.black
                                .opacity(isEditing ? 0.35 : 0)
                        }
                    if imageWidth >= 100 && !showOnlyThumbs {
                        TitleView
                            .frame(width: proxy.size.width, height: titleHeight, alignment: .topLeading)
                    }
                }
                .animation(.default, value: isEditing)
            }
        }

        var titleHeight: CGFloat {
            showTitleOnly ? 44 : 65
        }

        var TitleView: some View {
            VStack(alignment: .leading, spacing: 1.5) {
                Text(file.metaData?.formattedName ?? file.name)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !showTitleOnly {
                    SubHeadline
                }
            }
        }

        var SubHeadline: some View {
            HStack(spacing: 3) {
                Text(file.sizeToString()) // File Size
                if !file.isOnDevice && !isDownloading {
                    Text("•")
                    Image(systemName: "icloud.and.arrow.down")

                } else if let pageCount = file.pageCount {
                    let plural = pageCount == 1 ? "" : "s"
                    Text("•")
                    Text("\(pageCount) Page\(plural)")
                } else if isDownloading {
                    Text("•")
                    Text("Downloading")
                    Image(systemName: "icloud.and.arrow.down")
                        .shimmering()
                }
                Spacer()
            }
            .font(.footnote.weight(.thin))
            .lineLimit(1)
        }

        func request(size: CGSize) -> ImageRequest {
            file.imageRequest(size)
        }
    }
}

extension DirectoryViewer.CoreCollectionView {
    func LayoutBuilder(_ section: Int) -> ASCollectionLayoutSection {
        switch section {
        case 0:
            let isEmpty = directory.folders.isEmpty
            return .orthogonalGrid(gridSize: 2,
                                   itemDimension: .fractionalWidth(0.475),
                                   sectionDimension: !isEmpty ? .fractionalHeight(0.2) : .absolute(0),
                                   orthogonalScrollingBehavior: .groupPaging,
                                   gridSpacing: 7,
                                   itemInsets: .init(top: 3.5, leading: 0, bottom: 3.5, trailing: 10),
                                   sectionInsets: .init(top: 5, leading: 16, bottom: 5, trailing: 16))
        default:
            return ASCollectionLayoutSection { environment in
                let viewingPotrait = environment.container.contentSize.width < environment.container.contentSize.height
                let itemsPerRow = UserDefaults.standard.integer(forKey: viewingPotrait ? STTKeys.GridItemsPerRow_P : STTKeys.GridItemsPerRow_LS)
                let style = TileStyle(rawValue: UserDefaults.standard.integer(forKey: STTKeys.TileStyle)) ?? .COMPACT
                let SPACING: CGFloat = 10
                let INSET: CGFloat = 16
                let totalSpacing = SPACING * CGFloat(itemsPerRow - 1)
                let groupWidth = environment.container.contentSize.width - (INSET * 2) - totalSpacing
                let estimatedItemWidth = (groupWidth / CGFloat(itemsPerRow)).rounded(.down)
                let shouldAddTitle = (style == .SEPARATED && estimatedItemWidth >= 100) && !showOnlyThumbs
                let titleSize: CGFloat = shouldAddTitle ? (showTitleOnly ? 48 : 65) : 0
                let height = (estimatedItemWidth * 1.5) + titleSize
                // Item
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1 / CGFloat(itemsPerRow)),
                    heightDimension: .absolute(height)
                ))

                // Group / Row
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .absolute(height)
                    ),
                    subitem: item,
                    count: itemsPerRow
                )
                group.interItemSpacing = .fixed(SPACING)
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = .init(top: 5, leading: INSET, bottom: 10, trailing: INSET)
                section.interGroupSpacing = SPACING
                return section
            }
        }
    }
}
