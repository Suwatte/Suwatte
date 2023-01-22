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
import OrderedCollections

final class ExploreCollectionsController: UICollectionViewController {
    var source: DaisukeContentSource!
    typealias Snapshot = NSDiffableDataSourceSnapshot<AnyHashable, ContentData>
    typealias DataSource = UICollectionViewDiffableDataSource<AnyHashable, ContentData>
    typealias CollectionExcerpt = DSKCommon.CollectionExcerpt
    var snapshot = Snapshot()
    var model: ExploreView.ViewModel!
    var TAG_SECTION_ID = UUID().uuidString
    let refreshControl = UIRefreshControl()
    var tasks = [Task<Void, Never>?]()
    
    
    var loadingCache: [AnyHashable: Bool] = [:]
    var errorCache: [AnyHashable: Error] = [:]
    
    var library: OrderedSet<String> = []
    var savedForLater: OrderedSet<String> = []
    
    var libraryNotificationToken: NotificationToken?
    var sflNotificationToken: NotificationToken?
    var tileStyle: TileStyle! {
        didSet {
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    func disconnect() {
        libraryNotificationToken?.invalidate()
        sflNotificationToken?.invalidate()
        tasks.forEach { task in
            task?.cancel()
        }
        tasks.removeAll()
    }
    
    
    deinit {
        Logger.shared.debug("ExploreViewController Deallocated")
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
            if let data = item.content as? Err {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "errorCell", for: indexPath)
                cell.contentConfiguration = nil
                cell.contentConfiguration = UIHostingConfigurationBackport {
                    let error = errorCache[item.section] ?? DSK.Errors.NamedError(name: "Error", message: data.description)
                    ErrorView(error: error, sourceID: source.id) { [weak self] in
                        if case DSK.Errors.NetworkErrorCloudflareProtected = error {
                            self?.reloadAllSections()
                        } else if let excerpt = item.section as? CollectionExcerpt {
                            self?.reloadSingleSection(excerpt: excerpt)
                        } else {
                            self?.loadTags()
                        }
                    }
                }
                return cell
            }
            // Content Cell
            if let data = item.content as? DSKCommon.Highlight {
                let sourceId = source.id
                let excerpt = snapshot.sectionIdentifiers.get(index: indexPath.section) as? CollectionExcerpt
                guard let excerpt else { fatalError("excerpt not found") }
                let style = excerpt.style
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: excerpt.style.description, for: indexPath)
                let shouldShowPlaceholder = self.loadingCache[excerpt] ?? false
                cell.backgroundColor = .clear
                cell.contentConfiguration = nil
                let inLibrary = library.contains(data.contentId)
                let readLater = savedForLater.contains(data.contentId)
                cell.contentConfiguration = UIHostingConfigurationBackport {
                    ContentCell(data: data, style: style, sourceId: sourceId, placeholder: shouldShowPlaceholder, inLibrary: inLibrary, readLater: readLater)
                }
                return cell
            }
            // Tag Cell
            if let data = item.content as? DSKCommon.Tag {
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
        observeLibrary()

        if snapshot.sectionIdentifiers.isEmpty {
            loadTags()
            handleCollections()
        }

    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disconnect()
    }
    
    func observeLibrary() {
        let realm = try! Realm()
        
        let libraryResults = realm.objects(LibraryEntry.self).where({ $0.content.sourceId == source.id })
        let savedForLaterResults = realm.objects(ReadLater.self).where({ $0.content.sourceId == source.id })
        
        libraryNotificationToken = libraryResults.observe { [weak self] _ in
            self?.library = OrderedSet(libraryResults.compactMap(\.content?.contentId))
        }
        sflNotificationToken = savedForLaterResults.observe { [weak self] _ in
            self?.savedForLater = OrderedSet(savedForLaterResults.compactMap(\.content?.contentId))

        }
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
        let task = Task {
            do {
                let data = try await source.getExplorePageTags()
                errorCache.removeValue(forKey: TAG_SECTION_ID)
                if let data {
                    addTagSection()
                    snapshot.appendItems(data.map({ .init(section: TAG_SECTION_ID, content: $0) }), toSection: TAG_SECTION_ID)
                }
            } catch {
                addTagSection()
                snapshot.appendItems([.init(section: TAG_SECTION_ID, content: Err(description: error.localizedDescription))], toSection: TAG_SECTION_ID)
                errorCache[TAG_SECTION_ID] = error
            }
            await MainActor.run(body: {
                loadingCache.removeValue(forKey:TAG_SECTION_ID)
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
        if current.hashValue == collection.hashValue {
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
        snapshot.appendItems(DSKCommon.Highlight.placeholders().map({ .init(section: collection, content: $0) }), toSection: collection)
        await MainActor.run(body: { [DATA_SOURCE, snapshot] in
            DATA_SOURCE.apply(snapshot)
        })
        do {
            let data = try await source.resolveExplorePageCollection(collection)
            errorCache.removeValue(forKey: collection)
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
                snapshot.appendItems(items.map({ .init(section: excerpt, content: $0) }), toSection: excerpt)
                loadingCache[collection] = false
                try Task.checkCancellation()
                await MainActor.run(body: { [unowned self] in
                    DATA_SOURCE.apply(snapshot)
                })
            }
        } catch {
            // Handle Error
            Logger.shared.error("[ExploreViewController] \(error)", .init(function: #function))
            errorCache.updateValue(error, forKey: collection)
            // Add Placeholder Item
            let toBeDeleted = snapshot.itemIdentifiers(inSection: collection)
            snapshot.deleteItems(toBeDeleted)
            snapshot.appendItems([.init(section: collection, content: Err(description: error.localizedDescription))], toSection: collection)
            
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
            
            if snapshot.itemIdentifiers(inSection: section).first?.content is Err {
                return ErrorLayout()
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
    
    struct ContentData: Hashable {
        var section: AnyHashable
        var content: AnyHashable
    }
    struct ContentCell: View {
        var data: DSKCommon.Highlight
        var style: DSKCommon.CollectionStyle
        var sourceId: String
        var placeholder: Bool
        @EnvironmentObject var model: ExploreView.ViewModel
        @StateObject var manager = LocalAuthManager.shared
        @State var inLibrary: Bool
        @State var readLater: Bool
        @Preference(\.protectContent) var protectContent
        var body: some View {
            ZStack(alignment: .topTrailing) {
                ExploreView.HighlightTile(entry: data, style: style, sourceId: sourceId)
                    .onTapGesture(perform: {
                        if placeholder { return }
                        model.selection = (sourceId, data)
                    })
                    .buttonStyle(NeutralButtonStyle())
                    .conditional(!placeholder, transform: { view in
                        view
                            .contextMenu {
                                Button {
                                    if readLater {
                                        DataManager.shared.removeFromReadLater(sourceId, content: data.id)
                                    } else {
                                        DataManager.shared.addToReadLater(sourceId, data.id)
                                    }
                                    readLater.toggle()
                                } label: {
                                    Label(readLater ? "Remove from Read Later" : "Add to Read Later", systemImage: readLater ? "bookmark.slash" : "bookmark")
                                }
                            }
                    })
                if (inLibrary || readLater) && !shouldHide {
                    ColoredBadge(color: inLibrary ? .accentColor : .yellow)
                        .transition(.opacity)
                }
            }
            .shimmering(active: placeholder)
            .conditional(placeholder) { view in
                view.redacted(reason: .placeholder)
            }
            
            
        }
        var shouldHide: Bool {
            protectContent && manager.isExpired
        }
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
                if loader.view != nil { return }
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
