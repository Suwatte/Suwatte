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

final class ExploreCollectionsController: UICollectionViewController {
    var source: DSK.ContentSource!
    typealias Snapshot = NSDiffableDataSourceSnapshot<String, SectionObject>
    typealias DataSource = UICollectionViewDiffableDataSource<String, SectionObject>
    var cache: [String: DSKCommon.CollectionExcerpt] = [:]
    var errors: [String: Error] = [:]
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
                        let tile = object.hashable as? DSKCommon.Highlight
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
                        let tile = object.hashable as? DSKCommon.Highlight
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
                        let tile = object.hashable as? DSKCommon.Highlight
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
                        let tile = object.hashable as? DSKCommon.Highlight
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

    private lazy var DATA_SOURCE: DataSource = {
        let dataSource = DataSource(collectionView: collectionView) { [unowned self] collectionView, indexPath, item in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SwiftUICollectionViewCell.reuseIdentifier, for: indexPath) as? SwiftUICollectionViewCell else {
                fatalError("Failed to dequeue Cell")
            }

            cell.backgroundColor = .clear
            let sectionId = item.sectionId

            let excerpt = cache[sectionId]
            if let error = errors[sectionId] {
                cell.embed(in: self) {
                    ErrorView(error: error) { [weak self] in
                        if let excerpt = excerpt {
                            self?.removeSection(id: sectionId)
                            self?.reloadSingleSection(excerpt: excerpt)
                        }
                    }
                }
                return cell
            }

            if let data = item.hashable as? DSKCommon.Highlight {
                guard let style = cache[sectionId]?.style else {
                    return cell
                }
                let isInLibrary = inLibrary(data)
                let isSavedForLater = savedForLater(data)
                let sourceId = source.id
                cell.embed(in: self) {
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

                    .id(ItemIdentifier(sectionIDHash: indexPath.section.hashValue, itemIDHash: data.hashValue, inLibrary: isInLibrary, inSavedForLater: isSavedForLater, style: style))
                }
                return cell
            }
            if let data = item.hashable as? DSKCommon.Tag {
                cell.embed(in: self) {
                    Group {
                        if data.id == "stt_all_tags" {
                            AllTagsView()
                        } else {
                            TagTile(tag: data)
                        }
                    }
                    .id(ItemIdentifier(sectionIDHash: indexPath.section.hashValue, itemIDHash: data.hashValue))
                }
                return cell
            }
            return cell
        }

        dataSource.supplementaryViewProvider = { [unowned self] collectionView, kind, indexPath in
            switch kind {
            case UICollectionView.elementKindSectionHeader:
                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SwiftUICollectionViewCell.reuseIdentifier, for: indexPath) as? SwiftUICollectionViewCell else {
                    fatalError("Could Not Dequeue Header Cell")
                }
                let sectionId = DATA_SOURCE.sectionIdentifier(for: indexPath.section)
                guard let sectionId = sectionId else {
                    return header
                }

                if sectionId == TAG_SECTION_ID {
                    header.embed(in: self) { [unowned self] in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Explore Genres")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .id(ItemIdentifier(sectionIDHash: indexPath.section.hashValue, itemIDHash: TAG_SECTION_ID.hashValue))
                    }
                } else if let excerpt = getExcerpt(at: indexPath) {
                    header.embed(in: self) {
                        HeaderView(excerpt: excerpt, request: excerpt.request)
                            .id(ItemIdentifier(sectionIDHash: indexPath.section.hashValue, itemIDHash: excerpt.hashValue))
                    }
                }

                return header
            default: return nil
            }
        }

        return dataSource
    }()
}

private typealias CTR = ExploreCollectionsController
extension CTR {
    struct SectionObject: Hashable {
        var sectionId: String
        var hashable: AnyHashable
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.setCollectionViewLayout(getLayout(), animated: false)
        collectionView.register(SwiftUICollectionViewCell.self, forCellWithReuseIdentifier: SwiftUICollectionViewCell.reuseIdentifier)
        collectionView.register(SwiftUICollectionViewCell.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: SwiftUICollectionViewCell.reuseIdentifier)
        collectionView.backgroundColor = nil
        collectionView.backgroundView = nil

        refreshControl.tintColor = .init(named: "accentColor")
        refreshControl.addTarget(self, action: #selector(reload), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        listenToQueries()
        if cache.isEmpty, errors.isEmpty {
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
    func loadTags() {
        let task = Task {
            do {
                let data = try await source.getExplorePageTags()
                if var data = data {
                    data.append(.init(id: "stt_all_tags", label: "All", adultContent: false))
                    addSection(id: TAG_SECTION_ID)
                    snapshot.appendItems(data.map { .init(sectionId: TAG_SECTION_ID, hashable: $0) }, toSection: TAG_SECTION_ID)
                }
            } catch {
                addSection(id: TAG_SECTION_ID)
                errors.updateValue(error, forKey: TAG_SECTION_ID)
                snapshot.appendItems([.init(sectionId: TAG_SECTION_ID, hashable: "")], toSection: TAG_SECTION_ID)
            }
            await MainActor.run(body: {
                DATA_SOURCE.apply(snapshot)
            })
        }

        tasks.append(task)
    }

    func addSection(id: String) {
        if snapshot.sectionIdentifiers.contains(id) { return }
        snapshot.appendSections([id])
        reorderSections()
    }
    
    func reorderSections() {
        // Move Tags to Top, Latests to Bottom
        if snapshot.sectionIdentifiers.isEmpty { return }
        let ids = snapshot.sectionIdentifiers
        for id in ids {
            // Move Tags to Top
            if id == TAG_SECTION_ID && id != ids.first {
                snapshot.moveSection(id, beforeSection: ids.first! )
            }
            
            // Move Update List Style Collections to bottom
            if let style = cache[id]?.style, style == .UPDATE_LIST && id != ids.last {
                snapshot.moveSection(id, afterSection: ids.last!)
            }
        }
        
    }

    func removeSection(id: String) {
        snapshot.deleteSections([id])
        DATA_SOURCE.apply(snapshot)
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

    func handleLoadSection(collection: DSKCommon.CollectionExcerpt) async {
        let id = collection.id
        do {
            let data = try await source.resolveExplorePageCollection(collection)
            try Task.checkCancellation()
            let excerpt = cache[id]
            if var excerpt = excerpt {
                if let title = data.title {
                    excerpt.title = title
                }

                if let subtitle = data.subtitle {
                    excerpt.subtitle = subtitle
                }
                cache.updateValue(excerpt, forKey: id)
                let items: [SectionObject] = data
                    .highlights
//                    .distinct()
                    .map { .init(sectionId: id, hashable: $0) }
                snapshot.appendItems(items, toSection: id)

                await MainActor.run(body: { [DATA_SOURCE, snapshot] in
                    DATA_SOURCE.apply(snapshot)
                })
            }
        } catch {
            // Handle Error
            Logger.shared.error("[ExploreViewController] \(error)", .init(function: #function))
            errors.updateValue(error, forKey: id)
            // Add Placeholder Item
            let toBeDeleted = snapshot.itemIdentifiers.filter { $0.sectionId == id }
            snapshot.deleteItems(toBeDeleted)
            snapshot.appendItems([.init(sectionId: id, hashable: "")], toSection: id)

            await MainActor.run(body: { [DATA_SOURCE, snapshot] in
                DATA_SOURCE.apply(snapshot)
            })
        }
    }

    func reloadAllSections() {
        snapshot.deleteSections(snapshot.sectionIdentifiers)
        cache.removeAll()
        errors.removeAll()
        DATA_SOURCE.apply(snapshot)
        loadTags()
        handleCollections()
    }

    func reloadSingleSection(excerpt: DSKCommon.CollectionExcerpt) {
        addSection(id: excerpt.id)
        cache.updateValue(excerpt, forKey: excerpt.id)
        DATA_SOURCE.apply(snapshot)
        let task = Task {
            await handleLoadSection(collection: excerpt)
        }
        tasks.append(task)
    }

    func loadCollections() async throws {
        let collections = try await source
            .createExplorePageCollections()

        try Task.checkCancellation()
        await withTaskGroup(of: Void.self, body: { group in

            for collection in collections {
                await MainActor.run(body: {
                    // Create Section
                    addSection(id: collection.id)
                    self.cache.updateValue(collection, forKey: collection.id)
                    self.DATA_SOURCE.apply(self.snapshot)
                })
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
    func isFailing(at path: IndexPath) -> Bool {
        guard let section = DATA_SOURCE.sectionIdentifier(for: path.section) else {
            return true
        }
        return errors[section] != nil
    }

    func getLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [unowned self] section, environment in
            guard let section = DATA_SOURCE.sectionIdentifier(for: section) else {
                return nil
            }

            if errors[section] != nil {
                return ErrorLayout()
            }
            if section == TAG_SECTION_ID {
                return TagsLayout()
            }

            guard let excerpt = cache[section] else {
                return nil
            }

            switch excerpt.style {
            case .NORMAL: return NormalLayout()
            case .UPDATE_LIST: return LastestLayout(environment)
            case .GALLERY: return GalleryLayout(environment)
            case .INFO: return InfoLayout(environment)
            }
        }
        let config = layout.configuration
        config.interSectionSpacing = 25
        layout.configuration = config
        return layout
    }

    func getExcerpt(at path: IndexPath) -> DSKCommon.CollectionExcerpt? {
        let id = DATA_SOURCE.sectionIdentifier(for: path.section)
        guard let id = id else {
            return nil
        }

        return cache[id]
    }
}

// MARK: CELL

// Reference: https://medium.com/expedia-group-tech/swiftui-with-uicollectionview-aba7cbaf6d16
extension CTR {
    class SwiftUICollectionViewCell: UICollectionViewCell {
        var identifier = "SwiftUICollectionViewCell"
        /// Controller to host the SwiftUI View
        private(set) var host: UIHostingController<AnyView>?

        /// Add host controller to the heirarchy
        func embed<Content: View>(in parent: UIViewController, @ViewBuilder _ content: @escaping () -> Content)
        {
            let container = AnyView(content())
            if let controller = host {
                controller.rootView = container
                controller.view.layoutIfNeeded()
            } else {
                let controller = UIHostingController(rootView: container)

                parent.addChild(controller)
                controller.didMove(toParent: parent)
                contentView.addSubview(controller.view)
                controller.view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    controller.view.topAnchor.constraint(equalTo: topAnchor),
                    controller.view.bottomAnchor.constraint(equalTo: bottomAnchor),
                    controller.view.rightAnchor.constraint(equalTo: rightAnchor),
                    controller.view.leftAnchor.constraint(equalTo: leftAnchor),
                ])

                host = controller
            }
            host?.view.setNeedsLayout()
            host?.view.layoutIfNeeded()
            layoutIfNeeded()
        }

        // MARK: Controller + view clean up

        override func prepareForReuse() {
            super.prepareForReuse()
            removeHostController()
        }

        deinit {
            removeHostController()
        }

        func removeHostController() {
            for subview in contentView.subviews {
                subview.removeFromSuperview()
            }
            host?.willMove(toParent: nil)
            host?.view.removeFromSuperview()
            host?.removeFromParent()
            host = nil
        }

        static var reuseIdentifier = "SwiftUIView"
    }
}

// MARK: Supporting Views

extension CTR {
    struct ItemIdentifier: Hashable {
        var sectionIDHash: Int
        var itemIDHash: Int
        var inLibrary: Bool = false
        var inSavedForLater: Bool = false
        var style: DSKCommon.CollectionStyle? = nil
    }

    struct HeaderView: View {
        var excerpt: DSKCommon.CollectionExcerpt
        var request: DSKCommon.SearchRequest?
        @EnvironmentObject var source: DSK.ContentSource
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
        @EnvironmentObject var source: DSK.ContentSource
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
                    let req = try? await source.willRequestImage(request: .init(url: url.absoluteString))?.toURLRequest()
                    loader.load(req ?? url)
                }
                
            }
        }
        

        var request: DSKCommon.SearchRequest {
            .init(query: nil, page: 1, includedTags: [tag.id], excludedTags: [], sort: nil)
        }
    }

    struct AllTagsView: View {
        @EnvironmentObject var source: DSK.ContentSource
        var body: some View {
            NavigationLink(destination: ExploreView.AllTagsView().environmentObject(source)) {
                Text("View All \n\(Image(systemName: "arrow.right.circle"))")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(width: 150, height: 120)
                    .background(Color.accentColor)
                    .cornerRadius(7)
            }
            .buttonStyle(.plain)
        }
    }
}
