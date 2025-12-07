//
//  ProfileView+AdditionalInfo.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-18.
//

import SwiftUI

extension ProfileView.Skeleton {
    struct AdditionalInfoView: View {
        @EnvironmentObject var model: ProfileView.ViewModel
        var entry: DSKCommon.Content {
            model.content
        }

        var body: some View {
            VStack(alignment: .leading) {
                AdditionalProperties
                AdditionalTitles
            }
        }

        @ViewBuilder
        var AdditionalProperties: some View {
            if let props = entry.properties, props.count > 1 {
                ForEach(props[1...], id: \.title) { property in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(property.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                        ProfileView.Skeleton.PropertyTagsView(property: property, source: model.source)
                    }
                    .padding(.vertical, 2.5)
                }
            }
        }

        @ViewBuilder
        var AdditionalTitles: some View {
            if let titles = entry.additionalTitles, !titles.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Also Called...")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("\(titles.joined(separator: ", "))")
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 2.5)
            }
        }
    }

    struct AdditionalCoversView: View {
        @EnvironmentObject var model: ProfileView.ViewModel
        @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault

        @State var presentCovers = false
        var body: some View {
            if model.content.covers.count > 1 {
                GeometryReader { _ in
                    Text("")
                }
                VStack(alignment: .leading, spacing: 7) {
                    Divider()
                    Button { presentCovers.toggle() } label: {
                        HStack {
                            Text("Covers")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.leading)
                            Spacer()
                            Image(systemName: "photo")
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.fadedPrimary)
                    .cornerRadius(7)
                }
                .fullScreenCover(isPresented: $presentCovers) {
                    ProfileView.CoversSheet(covers: model.content.covers)
                        .accentColor(accentColor)
                        .tint(accentColor)
                }
            }
        }
    }
}
