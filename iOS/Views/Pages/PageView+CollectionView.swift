//
//  PageView+CollectionView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import SwiftUI
import ASCollectionView



extension DSKPageView {
    
    struct CollectionView: View {
        let page: DSKCommon.Page
        let runner: JSCRunner
        let tileModifier: PageItemModifier
        @State var locked = false
        @AppStorage(STTKeys.TileStyle) var tileStyle = TileStyle.SEPARATED
        @EnvironmentObject var model: ViewModel
        
        init(page: DSKCommon.Page, runner: JSCRunner, @ViewBuilder _ tileModifier: @escaping PageItemModifier) {
            self.page = page
            self.runner = runner
            self.tileModifier = tileModifier
        }
        var body: some View {
            ASCollectionView(sections: self.sections)
                .layout(self.layout)
                .shouldInvalidateLayoutOnStateChange(true)
                .onPullToRefresh({ endRefreshing in
                    model.loadable = .idle
                    endRefreshing()
                })
                .task { loadAll() }
                .onChange(of: tileStyle) { _ in } // Triggers view Update when key is updated
                
        }
    }
}

// MARK: - Load Methods
extension DSKPageView.CollectionView {
    func loadAll(force: Bool = false) {
        
        guard !locked && !force else { return }
        locked = true // prevent from refiring
        let unresolved = page.sections.filter({ $0.items == nil }).map(\.key)
        unresolved.forEach { section in
            Task.detached {
                await model.load(section)
            }
        }
    }
}

// MARK: - Layout
extension DSKPageView.CollectionView {
    var layout: ASCollectionLayout<String> {
        let cache = Dictionary(uniqueKeysWithValues: page.sections.map { ($0.key, $0.sectionStyle) })
        let errors = model.errors
        return ASCollectionLayout { sectionID in
            // Errored Out, Show Error Layout
            if errors.contains(sectionID)  {
                return .init {
                    ErrorLayout()
                }
            }
            // Either Loading or has loaded will show redacted placeholders to match
            switch cache[sectionID]! {
            case .GALLERY:
                return .init { environment in
                    GalleryLayout(environment)
                }
            case .INFO:
                return .init { environment in
                    InfoLayout(environment)
                }
            case .NORMAL:
                return .init {
                    NormalLayout()
                }
            case .UPDATE_LIST:
                return .init { environment in
                    LastestLayout(environment)
                }
            case .TAG:
                return .init {
                    NormalLayout()
                }
            }
        }
    }
}


// MARK: - Sections
extension DSKPageView.CollectionView {
    var sections: [ASCollectionViewSection<String>] {
        let loadables = model.loadables
        return page.sections.map { (section) -> ASCollectionViewSection<String> in
            let key = section.key
            // Section was preloaded
            if let data = section.items {
                return LoadedSection(section, data)
            }
            
            // Collection not loaded, find loadable and display based off state
            guard let loadable = loadables[key] else {
                return ErrorSection(section, error: DSK.Errors.ObjectConversionFailed)
            }
            
            switch loadable {
            case .failed(let error): return ErrorSection(section, error: error)
            case .loading, .idle: return LoadingSection(section)
            case .loaded(let data): return LoadedSection(section, data.items, data)
            }
        }
    }
}

extension DSKPageView.CollectionView {
    func buildHeader(_ title: String,_ subtitle: String?, _ link: DSKCommon.Linkable?) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .fontWeight(.light)
                        .opacity(0.75)
                }
            }
            Spacer()
            if let link {
                NavigationLink("View More \(Image(systemName: "chevron.right"))") {
                    Group {
                        if link.isPageLink, let pageLink = link.pageKey {
                            RunnerPageView(runner: runner, pageKey: pageLink)
                        } else {
                            RunnerDirectoryView(runner: runner, request: link.getDirectoryRequest())
                        }
                    }
                    .navigationBarTitle(title)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.accentColor)
                .font(.caption)
            }
        }
    }
}

// MARK: - Section Builders

extension DSKPageView.CollectionView {
    func PageNotFoundSection(_ section: DSKCommon.PageSection) -> ASCollectionViewSection<String> {
        ASCollectionViewSection(id: section.key) {
            Text("Section not found.")
        }
        .sectionHeader {
            buildHeader(section.title,
                        section.subtitle,
                        section.viewMoreLink)
        }
        .sectionFooter {
            EmptyView()
        }
    }
    func ErrorSection(_ section: DSKCommon.PageSection, error: Error) -> ASCollectionViewSection<String> {
        ASCollectionViewSection(id: section.key) {
            ErrorView(error: error, runnerID: runner.id) {
                Task.detached {
                    await model.load(section.key)
                }
            }
        }
        .sectionHeader {
            buildHeader(section.title,
                        section.subtitle,
                        section.viewMoreLink)
        }
        .sectionFooter {
            EmptyView()
        }
    }
    func LoadedSection(_ section: DSKCommon.PageSection , _ items: [DSKCommon.PageSectionItem], _ resolved: DSKCommon.ResolvedPageSection? = nil) -> ASCollectionViewSection<String> {
        ASCollectionViewSection(id: section.key, data: items, dataID: \.hashValue) { data, context in
            Group {
                if data.isPageLink, let pageKey = data.toPageLink().link.pageKey {
                    NavigationLink {
                        RunnerPageView(runner: runner, pageKey: pageKey)
                    } label: {
                        PageViewTile(entry: data, runnerID: runner.id)
                    }
                    .buttonStyle(NeutralButtonStyle())
                } else {
                    tileModifier(data)
                }
            }
                .environment(\.pageSectionStyle, section.sectionStyle)
        }
        .sectionHeader {
            buildHeader(resolved?.updatedTitle ?? section.title,
                        resolved?.updatedSubtitle ?? section.subtitle,
                        resolved?.viewMoreLink ?? section.viewMoreLink)
        }
        .sectionFooter {
            EmptyView()
        }
    }
    
    func LoadingSection(_ section: DSKCommon.PageSection) -> ASCollectionViewSection<String>  {
        ASCollectionViewSection(id: section.key) {
            ProgressView()
        }
        .sectionHeader {
            buildHeader(section.title,
                        section.subtitle,
                        section.viewMoreLink)
        }
        .sectionFooter {
            EmptyView()
        }
    }
}

// MARK: - Define Secton Style Environment Key
private struct PageSectionStyleKey: EnvironmentKey {
    static let defaultValue = DSKCommon.SectionStyle.NORMAL
}

extension EnvironmentValues {
  var pageSectionStyle: DSKCommon.SectionStyle {
    get { self[PageSectionStyleKey.self] }
    set { self[PageSectionStyleKey.self] = newValue }
  }
}
