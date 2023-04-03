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
        @State var expand = false
        @EnvironmentObject var model: ProfileView.ViewModel

        var entry: DSKCommon.Content {
            model.content
        }

        var summary: String? {
            entry.summary
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(entry.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .textSelection(.enabled)

                    Spacer()
                }
                if let summary, summary.trimmingCharacters(in: .whitespacesAndNewlines).count != 0 {
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

    struct CorePropertiesView: View {
        @EnvironmentObject var model: ProfileView.ViewModel
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                if let properties = model.content.properties, !properties.isEmpty, let core = properties.get(index: 0) {
                    PropertyTagsView(property: core, source: model.source)
                }
            }
        }
    }

    struct PropertyTagsView: View {
        var property: DSKCommon.Property
        var source: AnyContentSource
        var body: some View {
            InteractiveTagView(property.tags) { tag in
                NavigationLink(destination: ExploreView.SearchView(model: .init(request: generateSearchRequest(tagId: tag.id, propertyId: property.id), source: source), tagLabel: tag.label)) {
                    Text(tag.label)
                        .modifier(ProfileTagStyle())
                }
                .buttonStyle(.plain)
            }
        }

        fileprivate func generateSearchRequest(tagId: String, propertyId: String) -> DaisukeEngine.Structs.SearchRequest {
            .init(page: 1, filters: [.init(id: propertyId, included: [tagId])])
        }
    }
}

struct ProfileTagStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.callout.weight(.semibold))
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(Color.primary.opacity(0.1))
            .foregroundColor(Color.primary)
            .cornerRadius(5)
    }
}
