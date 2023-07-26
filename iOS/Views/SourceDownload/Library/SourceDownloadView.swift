//
//  SourceDownloadView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-25.
//

import SwiftUI

struct SourceDownloadView: View {
    @StateObject var model = ViewModel()
    @AppStorage(STTKeys.DownloadsSortLibrary) var sortOption: SortOption = .downloadCount
    @State var isAscending = true
    
    var body: some View {
        ZStack {
            CollectionView()
                .opacity(!model.entries.isEmpty && model.initialFetchComplete ? 1 : 0) // Work is complete and there are results
                .transition(.opacity)
            
            ProgressView()
                .opacity(model.working && model.entries.isEmpty && !model.initialFetchComplete ? 1 : 0) // Work is not complete and there are no results
                .transition(.opacity)
            
            NoResultsView()
                .opacity(!model.working && model.entries.isEmpty && model.initialFetchComplete ? 1 : 0) // work is complete and there are no results
                .transition(.opacity)
            
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Divider()
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(SortOption.allCases) {
                            Text($0.description)
                                .tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    Button { isAscending.toggle() } label: {
                        Label("Order", systemImage: isAscending ? "chevron.down" : "chevron.up")
                    }

                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .searchable(text: $model.text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
        .environmentObject(model)
        .task {
            model.watch(sortOption, isAscending)
        }
        .onDisappear(perform: model.stop)
        .onChange(of: sortOption) { newValue in
            model.watch(newValue, isAscending)
        }
        .onChange(of: isAscending) { newValue in
            model.watch(sortOption, newValue)
        }
        .onChange(of: model.text) { _ in
            model.working = true
        }
        .onReceive(model.$text.debounce(for: .seconds(0.15), scheduler: DispatchQueue.main).dropFirst()) { _ in
            model.watch(sortOption, isAscending)
        }

        .navigationBarTitle("Downloads")
        .navigationBarTitleDisplayMode(.inline)
    }
}


extension SourceDownloadView {
    struct NoResultsView: View {
        @EnvironmentObject var model: ViewModel
        var body: some View {
            VStack {
                Text(isSearching ? "┐(´～｀)┌" : "(ᅌᴗᅌ✿)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(isSearching ? "no results" : "no downloads\ntitles you download from sources will show up here.")
                    .font(.subheadline)
                    .fontWeight(.light)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(.gray)
        }
        
        var isSearching: Bool {
            !model.text.isEmpty
        }
    }
}

extension SourceDownloadView {
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
    var color: Color = .accentColor
    private let height: CGFloat = 17
    var body: some View {
        ZStack(alignment: .center) {
            Capsule()
                .foregroundColor(.systemBackground)
            ZStack(alignment: .center) {
                Capsule()
                    .foregroundColor(color)
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
