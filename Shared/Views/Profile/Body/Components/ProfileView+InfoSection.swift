//
//  ProfileView+Summary.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import Foundation
import SwiftUI

extension ProfileView.Skeleton {
    struct Summary: View {
        @EnvironmentObject var entry: StoredContent
        @State var expand = false
        var summary: String {
            entry.summary
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(entry.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                if summary.trimmingCharacters(in: .whitespacesAndNewlines).count != 0 {
                    MarkDownView(text: summary)
                        .lineLimit(expand ? nil : 3)
                        .padding(.top, 5.0)
                        .onTapGesture {
                            withAnimation { expand.toggle() }
                        }
                } else { EmptyView() }
            }
            .frame(maxHeight: .infinity)
        }
    }

    var CorePropertySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if entry.properties.count >= 1 {
                PropertyTagsView(property: entry.properties[0], source: viewModel.source)
            }
        }
    }

    struct PropertyTagsView: View {
        var property: StoredProperty
        var source: DaisukeEngine.ContentSource
        var body: some View {
            InteractiveTagView(property.tags) { tag in
                NavigationLink(destination: ExploreView.SearchView(model: .init(request: generateSearchRequest(tagId: tag.id), source: source), tagLabel: tag.label)) {
                    Text(tag.label)
                        .fontWeight(.semibold)
                        .font(.callout)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .background(Color.primary.opacity(0.1))
                        .foregroundColor(Color.primary)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
        }

        fileprivate func generateSearchRequest(tagId: String) -> DaisukeEngine.Structs.SearchRequest {
            .init(page: 1, includedTags: [tagId])
        }
    }
}
