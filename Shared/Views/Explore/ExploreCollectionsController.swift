//
//  EV+InfoSection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-27.
//

import Combine
import NukeUI
import RealmSwift
import SwiftUI
import UIKit
import UIHostingConfigurationBackport
import SkeletonView

final class ExploreCollectionsController: UICollectionViewController {
    var source: DaisukeContentSource!
    typealias Snapshot = NSDiffableDataSourceSnapshot<AnyHashable, AnyHashable>
    typealias DataSource = UICollectionViewDiffableDataSource<AnyHashable, AnyHashable>
    typealias CollectionExcerpt = DSKCommon.CollectionExcerpt
    var snapshot = Snapshot()
    var model: ExploreView.ViewModel!
    var TAG_SECTION_ID = UUID().uuidString
    var libraryResultNotificationToken: NotificationToken?
    var readLaterResultNoticationToken: NotificationToken?
    let refreshControl = UIRefreshControl()
    var deletedRLIds: [String] = []
    var library: Results<LibraryEntry>?
    var savedForLater: Results<ReadLater>?
    var tasks = [Task<Void, Never>?]()
    
    
    var loadingCache: [AnyHashable: Bool] = [:]
    var tileStyle: TileStyle! {
        didSet {
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    func disconnect() {
        tasks.forEach { task in
            task?.cancel()
        }
        tasks.removeAll()
        libraryResultNotificationToken?.invalidate()
        readLaterResultNoticationToken?.invalidate()
        library = nil
        savedForLater = nil
        if let tileStyleObserver = tileStyleObserver {
            NotificationCenter.default.removeObserver(tileStyleObserver)
        }
    }
    
    var tileStyleObserver: NSObjectProtocol?
    
    deinit {
        Logger.shared.debug("ExploreViewController Deallocated")
    }
    
    func listenToQueries() {
        let realm = try! Realm()
        
        // Library
        library = realm
            .objects(LibraryEntry.self)
            .where { $0.content.sourceId == self.source.id }
        
        libraryResultNotificationToken = library?.observe { change in
            switch change {
                case let .initial(results):
                    let ids = results
                        .compactMap { $0.content?.contentId }
                    let toUpdate = self
                        .snapshot
                        .itemIdentifiers
                        .filter { object in
                            let tile = object as? DSKCommon.Highlight
                            guard let tile = tile else {
                                return false
                            }
                            
                            return ids.contains(tile.id)
                        }
                    self.snapshot.reconfigureItems(toUpdate)
                    self.DATA_SOURCE.apply(self.snapshot, animatingDifferences: false, completion: nil)
                    self.deletedRLIds.removeAll()
                    
                case .update(let results, deletions: _, insertions: let insertions, modifications: let modificaitons):
                    var updatedIds = insertions.compactMap { results[$0].content?.contentId }
                    updatedIds.append(contentsOf: modificaitons.compactMap { results[$0].content?.contentId })
                    let toUpdate = self
                        .snapshot
                        .itemIdentifiers
                        .filter { object in
                            let tile = object as? DSKCommon.Highlight
                            guard let tile = tile else {
                                return false
                            }
                            
                            return updatedIds.contains(tile.id)
                        }
                    self.snapshot.reconfigureItems(toUpdate)
                    self.DATA_SOURCE.apply(self.snapshot, animatingDifferences: false, completion: nil)
                    self.deletedRLIds.removeAll()
                    
                default: break
            }
        }
        // Saved For Later
        savedForLater = realm
            .objects(ReadLater.self)
            .where { $0.content.sourceId == self.source.id }
        
        readLaterResultNoticationToken = savedForLater?.observe { change in
            switch change {
                case let .initial(results):
                    let ids = results
                        .compactMap { $0.content?.contentId }
                    let toUpdate = self
                        .snapshot
                        .itemIdentifiers
                        .filter { object in
                            let tile = object as? DSKCommon.Highlight
                            guard let tile = tile else {
                                return false
                            }
                            
                            return ids.contains(tile.id)
                        }
                    self.snapshot.reconfigureItems(toUpdate)
                    self.DATA_SOURCE.apply(self.snapshot, animatingDifferences: false, completion: nil)
                    self.deletedRLIds.removeAll()
                case .update(let results, deletions: _, insertions: let insertions, modifications: let modificaitons):
                    var updatedIds = insertions.compactMap { results[$0].content?.contentId }
                    updatedIds.append(contentsOf: self.deletedRLIds)
                    updatedIds.append(contentsOf: modificaitons.compactMap { results[$0].content?.contentId })
                    let toUpdate = self
                        .snapshot
                        .itemIdentifiers
                        .filter { object in
                            let tile = object as? DSKCommon.Highlight
                            guard let tile = tile else {
                                return false
                            }
                            
                            return updatedIds.contains(tile.id)
                        }
                    self.snapshot.reconfigureItems(toUpdate)
                    self.DATA_SOURCE.apply(self.snapshot, animatingDifferences: false, completion: nil)
                    self.deletedRLIds.removeAll()
                default: break
            }
        }
    }
    
    func inLibrary(_ entry: DSKCommon.Highlight) -> Bool {
        library?
            .contains(where: { $0.content?.sourceId == source.id && $0.content?.contentId == entry.id }) ?? false
    }
    
    func savedForLater(_ entry: DSKCommon.Highlight) -> Bool {
        savedForLater?
            .contains(where: { $0.content?.sourceId == source.id && $0.content?.contentId == entry.id }) ?? false
    }
    
    // MARK: DataSource
    func getExcerpt(id: String) -> CollectionExcerpt? {
        snapshot
            .sectionIdentifiers
            .first { ($0 as? CollectionExcerpt)?.id == id } as? CollectionExcerpt
    }
    
    private lazy var DATA_SOURCE: DataSource  = {
        let dataSource = DataSource(collectionView: collectionView) { [unowned self] collectionView, indexPath, item in
            // Error Cell
            if let data = item as? Err {
                let excerpt = snapshot.sectionIdentifiers.get(index: indexPath.section) as? CollectionExcerpt
                guard let excerpt else { fatalError("excerpt not found") }
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "errorCell", for: indexPath)
                cell.contentConfiguration = nil
                cell.contentConfiguration = UIHostingConfigurationBackport {
                    ErrorView(error: DSK.Errors.NamedError(name: "Error", message: data.description)) { [weak self] in
                        self?.reloadSingleSection(excerpt: excerpt)
                    }
                }
                return cell
            }
            // Content Cell
            if let data = item as? DSKCommon.Highlight {
                let isInLibrary = inLibrary(data)
                let isSavedForLater = savedForLater(data)
                let sourceId = source.id
                let excerpt = snapshot.sectionIdentifiers.get(index: indexPath.section) as? CollectionExcerpt
                guard let excerpt else { fatalError("excerpt not found") }
                let style = excerpt.style
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: excerpt.style.description, for: indexPath)
                let shouldShowPlaceholder = self.loadingCache[excerpt] ?? false
                cell.backgroundColor = .clear
                cell.contentConfiguration = nil
                cell.contentConfiguration = UIHostingConfigurationBackport {
                    ZStack(alignment: .topTrailing) {
                        ExploreView.HighlightTile(entry: data, style: style, sourceId: sourceId)
                            .onTapGesture(perform: { [weak self] in
                                self?.model.selection = (sourceId, data)
                            })
                            .buttonStyle(NeutralButtonStyle())
                            .contextMenu {
                                Button { [weak self] in
                                    if isSavedForLater {
                                        self?.deletedRLIds.append(data.id)
                                        DataManager.shared.removeFromReadLater(sourceId, content: data.id)
                                    } else {
                                        DataManager.shared.addToReadLater(sourceId, data.id)
                                    }
                                } label: {
                                    Label(isSavedForLater ? "Remove from Read Later" : "Add to Read Later", systemImage: isSavedForLater ? "bookmark.slash" : "bookmark")
                                }
                            }
                        
                        if isInLibrary || isSavedForLater {
                            ColoredBadge(color: isInLibrary ? .accentColor : .yellow)
                                .transition(.opacity)
                        }
                    }
                    .shimmering(active: shouldShowPlaceholder)
                    .conditional(shouldShowPlaceholder) { view in
                        view.redacted(reason: .placeholder)
                    }
                }
                return cell
            }
            // Tag Cell
            if let data = item as? DSKCommon.Tag {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "tagCell", for: indexPath)
                cell.contentConfiguration = nil
                cell.contentConfiguration = UIHostingConfigurationBackport {
                    TagTile(tag: data)
                }
                return cell
            }
            
            return nil
        }
        
        dataSource.supplementaryViewProvider = { [unowned self] collectionView, kind, indexPath in
            if kind != UICollectionView.elementKindSectionHeader { fatalError("Should Only Be Header") }
            let section = DATA_SOURCE.sectionIdentifier(for: indexPath.section)
            guard let section else { fatalError("Section Not Found") }
            if let section = section as? String, section == TAG_SECTION_ID {
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "tagHeaderCell", for: indexPath)
                guard let header = header as? UICollectionViewCell else { fatalError("Invalid Header") }
                header.contentConfiguration = nil
                header.contentConfiguration = UIHostingConfigurationBackport {
                    TagHeaderView()
                }
                return header
            }
            
            if let section = section as? CollectionExcerpt {
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "sectionHeaderCell", for: indexPath)
                guard let header = header as? UICollectionViewCell else { fatalError("Invalid Header") }
                header.contentConfiguration = nil
                header.contentConfiguration = UIHostingConfigurationBackport {
                    HeaderView(excerpt: section, request: section.request)
                }
                return header
            }
            fatalError("Failed To Return Cell")
        }
        
        return dataSource
    }()
}

private typealias CTR = ExploreCollectionsController
extension CTR {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.setCollectionViewLayout(getLayout(), animated: false)
        DSKCommon.CollectionStyle.allCases.forEach {
            collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: $0.description)
        }
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "tagCell")
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "errorCell")
        collectionView.register(UICollectionViewCell.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "tagHeaderCell")
        collectionView.register(UICollectionViewCell.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeaderCell")
        
        collectionView.backgroundColor = nil
        collectionView.backgroundView = nil
        
        let data = UserDefaults.standard.string(forKey: STTKeys.AppAccentColor)
        refreshControl.tintColor = .init(data.flatMap({ Color(rawValue: $0) }) ?? .gray)
        refreshControl.addTarget(self, action: #selector(reload), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        listenToQueries()
        if snapshot.sectionIdentifiers.isEmpty {
            loadTags()
            handleCollections()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disconnect()
    }
}

extension CTR {
    
    func addTagSection() {
        snapshot.deleteSections([TAG_SECTION_ID])
        if snapshot.sectionIdentifiers.isEmpty {
            snapshot.appendSections([TAG_SECTION_ID])
        } else {
            let firstSection = snapshot.sectionIdentifiers.first!
            snapshot.insertSections([TAG_SECTION_ID], beforeSection: firstSection)
        }
    }
    func loadTags() {
        addTagSection()
        let task = Task {
            do {
                let data = try await source.getExplorePageTags()
                if let data {
                    snapshot.appendItems(data, toSection: TAG_SECTION_ID)
                }
            } catch {
                snapshot.appendItems([Err(description: error.localizedDescription)], toSection: TAG_SECTION_ID)
            }
            await MainActor.run(body: {
                DATA_SOURCE.apply(snapshot)
            })
        }
        
        tasks.append(task)
    }
    
    func handleCollections() {
        let task = Task {
            do {
                try await loadCollections()
            } catch {
                Logger.shared.error("[ExploreViewController] \(error.localizedDescription)", .init(function: #function, line: #line))
            }
        }
        
        tasks.append(task)
    }
    
    func updateSectionExcerpt(with collection: CollectionExcerpt) {
        guard let current = getExcerpt(id: collection.id) else {
            snapshot.appendSections([collection])
            return
        }
        if current == collection {
            return
        }
        snapshot.insertSections([collection], beforeSection: current)
        snapshot.deleteSections([current])
    }
    
    func updateOrder() {
        for elem in snapshot.sectionIdentifiers {
            guard let elem = elem as? CollectionExcerpt else { continue }
            if elem.style == .UPDATE_LIST && !snapshot.sectionIdentifiers.isEmpty && snapshot.indexOfSection(elem) != (snapshot.sectionIdentifiers.count - 1) {
                snapshot.moveSection(elem, afterSection: snapshot.sectionIdentifiers.last!)
            }
        }
    }
    func handleLoadSection(collection: DSKCommon.CollectionExcerpt) async {
        let id = collection.id
        let toBeDeleted = snapshot.itemIdentifiers(inSection: collection)
        snapshot.deleteItems(toBeDeleted)
        loadingCache[collection] = true
        snapshot.appendItems(DSKCommon.Highlight.placeholders(), toSection: collection)
        await MainActor.run(body: { [DATA_SOURCE, snapshot] in
            DATA_SOURCE.apply(snapshot)
        })
        do {
            let data = try await source.resolveExplorePageCollection(collection)
            try Task.checkCancellation()
            let excerpt = getExcerpt(id: id)
            if var excerpt = excerpt {
                if let title = data.title {
                    excerpt.title = title
                }
                
                if let subtitle = data.subtitle {
                    excerpt.subtitle = subtitle
                }
                
                let items = data
                    .highlights
                updateSectionExcerpt(with: excerpt)
                let toBeDeleted = snapshot.itemIdentifiers(inSection: excerpt)
                snapshot.deleteItems(toBeDeleted)
                snapshot.appendItems(items, toSection: excerpt)
                loadingCache[collection] = false

                await MainActor.run(body: { [DATA_SOURCE, snapshot] in
                    DATA_SOURCE.apply(snapshot)
                })
            }
        } catch {
            // Handle Error
            Logger.shared.error("[ExploreViewController] \(error)", .init(function: #function))
            // Add Placeholder Item
            let toBeDeleted = snapshot.itemIdentifiers(inSection: collection)
            snapshot.deleteItems(toBeDeleted)
            snapshot.appendItems([Err(description: error.localizedDescription)], toSection: collection)
            
            await MainActor.run(body: { [DATA_SOURCE, snapshot] in
                DATA_SOURCE.apply(snapshot)
            })
        }
    }
    
    func reloadAllSections() {
        let allItems = snapshot.itemIdentifiers
        snapshot.deleteItems(allItems)
        DATA_SOURCE.apply(snapshot)
        loadTags()
        handleCollections()
    }
    
    func reloadSingleSection(excerpt: DSKCommon.CollectionExcerpt) {
        let items = snapshot.itemIdentifiers(inSection: excerpt)
        snapshot.deleteItems(items)
        let task = Task {
            await handleLoadSection(collection: excerpt)
        }
        tasks.append(task)
    }
    
    func loadCollections() async throws {
        let collections = try await source
            .createExplorePageCollections()
        
        
        try Task.checkCancellation()
        collections.forEach {
            self.updateSectionExcerpt(with: $0)
        }
        let toRemove = self.snapshot.sectionIdentifiers.filter({ $0 is CollectionExcerpt && !collections.contains($0 as! CollectionExcerpt) })
        self.snapshot.deleteSections(toRemove)
        updateOrder()
        
        await MainActor.run(body: {
            self.DATA_SOURCE.apply(self.snapshot)
        })
        
        try Task.checkCancellation()
        
        await withTaskGroup(of: Void.self, body: { group in
            
            for collection in collections {
                group.addTask { [weak self] in
                    // Resolve Section
                    await self?.handleLoadSection(collection: collection)
                }
            }
        })
    }
    
    @objc func reload() {
        collectionView.refreshControl?.beginRefreshing()
        reloadAllSections()
        collectionView.refreshControl?.endRefreshing()
    }
}

extension CTR {
    
    func getLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [unowned self] section, environment in
            guard let section = DATA_SOURCE.sectionIdentifier(for: section) else {
                return NormalLayout()
            }
            
            if let section = section as? String, section == TAG_SECTION_ID {
                return TagsLayout()
            }
            if let section = section as? CollectionExcerpt {
                switch section.style {
                    case .NORMAL: return NormalLayout()
                    case .UPDATE_LIST: return LastestLayout(environment)
                    case .GALLERY: return GalleryLayout(environment)
                    case .INFO: return InfoLayout(environment)
                }
            }
            return NormalLayout()
        }
        let config = layout.configuration
        config.interSectionSpacing = 20
        layout.configuration = config
        return layout
    }
}

// MARK: Supporting Views

extension CTR {
    struct Err: Hashable {
        var description: String
    }
    
    struct TagHeaderView: View {
        @AppStorage(STTKeys.AppAccentColor) var color = Color.sttDefault
        @EnvironmentObject var source: DaisukeContentSource
        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text("Explore Genres")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                Spacer()
                NavigationLink(destination: ExploreView.AllTagsView().environmentObject(source)) {
                    Text("View All")
                        .foregroundColor(color)
                        .fontWeight(.light)
                }
                .buttonStyle(.plain)
            }
        }
    }
    struct HeaderView: View {
        var excerpt: DSKCommon.CollectionExcerpt
        var request: DSKCommon.SearchRequest?
        @EnvironmentObject var source: DaisukeContentSource
        var body: some View {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Text(excerpt.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    if let subtitle = excerpt.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .fontWeight(.light)
                            .opacity(0.75)
                    }
                }
                Spacer()
                if let request = request {
                    NavigationLink("More") {
                        ExploreView.SearchView(model: .init(request: request, source: source))
                    }
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width - 20)
        }
    }
    
    struct TagTile: View {
        var tag: DSKCommon.Tag
        @State var color: Color = .fadedPrimary
        @EnvironmentObject var source: DaisukeContentSource
        @StateObject private var loader = FetchImage()
        
        var body: some View {
            NavigationLink(destination: ExploreView.SearchView(model: .init(request: request, source: source), tagLabel: tag.label)) {
                ZStack(alignment: .bottom) {
                    Group {
                        if let view = loader.view {
                            view
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 120)
                    .background(Color.accentColor.opacity(0.80))
                    .clipped()
                    .shimmering(active: loader.isLoading)
                    
                    Text(tag.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.all, 2.5)
                        .frame(width: 150, height: 25, alignment: .center)
                        .background(color)
                        .foregroundColor(color.isDark ? .white : .black)
                }
                .frame(width: 150)
                .cornerRadius(7)
                .animation(.default, value: color)
            }
            .buttonStyle(NeutralButtonStyle())
            .task {
                loader.animation = .default
                loader.onSuccess = { result in
                    if let avgColor = result.image.averageColor {
                        color = Color(uiColor: avgColor)
                    }
                }
                if let str = tag.imageUrl, let url = URL(string: str) {
                    let req = try? await(source as? DSK.LocalContentSource)?.willRequestImage(request: .init(url: url.absoluteString))?.toURLRequest()
                    loader.load(req ?? url)
                }
            }
        }
        
        var request: DSKCommon.SearchRequest {
            .init(query: nil, page: 1, includedTags: [tag.id], excludedTags: [], sort: nil)
        }
    }
}
