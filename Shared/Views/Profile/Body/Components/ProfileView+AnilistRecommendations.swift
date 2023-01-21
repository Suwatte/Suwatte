//
//  ProfileView+AnilistRecommendations.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-20.
//

import SwiftUI


extension ProfileView {
    struct AnilistRecommendationSection: View {
        typealias Response = Anilist.RecommendationResponse.PathObject
        var id: Int
        @State var loadable : Loadable<Response> = .idle
        var body: some View {
            LoadableView(load, loadable) { value in
                if value.nodes.isEmpty {
                    EmptyView()
                } else {
                    CoreView(data: value)
                }
            }
        }
        
        func load() {
            loadable = .loading
            Task {
                do {
                    let data = try await Anilist.shared.getRecommendations(for: id )
                    loadable = .loaded(data)
                } catch {
                    loadable = .failed(error)
                }
            }
        }
    }
}


extension ProfileView.AnilistRecommendationSection {
    
    struct CoreView: View {
        var data: Response
        @EnvironmentObject var model: ProfileView.ViewModel
        
        var body: some View {
            VStack(alignment: .leading) {
                HStack {
                    Image("anilist")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 35, height: 35)
                        .cornerRadius(7)
                    Text("More Like \(model.content.title)")
                        .font(.headline.weight(.semibold))
                }
                .padding(.horizontal)
                
                ScrollView(.horizontal,showsIndicators: false) {
                    HStack {
                        ForEach(data.nodes, id: \.mediaRecommendation.id) {
                            Cell(data: $0.mediaRecommendation)
                        }
                    }
                    .padding(.horizontal)
                }
                
            }
        }
    }
    
}

extension ProfileView.AnilistRecommendationSection.CoreView {
    struct Cell: View {
        var data: Anilist.RecommendationResponse.Excerpt
        @AppStorage(STTKeys.TileStyle) var style = TileStyle.SEPARATED

        var body: some View {
            NavigationLink {
                AnilistView.ProfileView(entry: .init(id: data.id, title: data.title.userPreferred)) { _, _ in
                }
            } label: {
                DefaultTile(entry: .init(contentId: data.id.description, cover: data.coverImage.large, title: data.title.userPreferred))
                    .frame(width: 150, height: CELL_HEIGHT)
                
            }
            .buttonStyle(NeutralButtonStyle())
        }
        
        
        var CELL_HEIGHT: CGFloat {
            var height = 150 * 1.5
            
            if style == .SEPARATED {
                height += 50
            }
            
            return height
        }
    }
}
