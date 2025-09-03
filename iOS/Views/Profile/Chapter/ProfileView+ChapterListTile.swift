//
//  ProfileView+ChapterListTile.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-18.
//

import FlagKit
import RealmSwift
import SwiftUI

struct ChapterListTile: View {
    let chapter: ThreadSafeChapter
    let isCompleted: Bool
    let isNewChapter: Bool
    let progress: Double?
    let download: DownloadStatus?
    let isLinked: Bool
    let showLanguageFlag: Bool
    let showDate: Bool
    let isBookmarked: Bool

    var body: some View {
        HStack(spacing: 7) {
            if let url = chapter.thumbnail.flatMap({ URL(string: $0) }) {
                STTImageView(url: url, identifier: chapter.contentIdentifier)
                    .frame(width: 60, height: 75)
                    .cornerRadius(7)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    DisplayNameView
                    Spacer()

                    HStack {
                        ProgressSubview
                        DownloadIndicatorView
                        IsNewView
                        LinkedIndicator
                        BookmarkedIndicator
                    }
                    .font(.caption.weight(.light))
                }

                HStack {
                    if showLanguageFlag {
                        LanguageView(chapter.language)
                    }
                    if hasProviders {
                        ScanlatorView()
                    }

                    if showLanguageFlag || hasProviders {
                        Spacer()
                    }
                    if showDate {
                        Text(chapter.date.timeAgoGrouped())
                    }

                    if !showLanguageFlag && !hasProviders && showDate {
                        Spacer()
                    }

                    if !showLanguageFlag && !hasProviders && !showDate {
                        Text(chapter.number.description)
                    }
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(Color.gray.opacity(0.5))
            }
        }
        .contentShape(Rectangle())
    }

    var hasProviders: Bool {
        chapter.providers != nil && !chapter.providers!.isEmpty
    }

    @ViewBuilder
    var DisplayNameView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(chapter.displayName)
                .lineLimit(1)
                .font(.headline)
                .foregroundColor(!isCompleted ? Color.primary : Color.gray.opacity(0.5))
            Text(chapter.title ?? chapter.chapterName)
                .font(.footnote)
                .fontWeight(.semibold)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(Color.gray.opacity(isCompleted ? 0.5 : 0.65))
        }
    }

    @ViewBuilder
    var IsNewView: some View {
        if isNewChapter && progress == nil && download == nil {
            Circle()
                .foregroundColor(.blue)
                .frame(width: 8, height: 8, alignment: .center)
        }
    }

    @ViewBuilder
    var LinkedIndicator: some View {
        if isLinked {
            Image(systemName: "link")
                .resizable()
                .scaledToFit()
                .foregroundColor(.primary.opacity(0.5))
                .frame(width: 15, height: 15, alignment: .center)
        }
    }

    @ViewBuilder
    var BookmarkedIndicator: some View {
        if isBookmarked {
            Image(systemName: "bookmark.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.primary.opacity(0.5))
                .frame(width: 15, height: 15, alignment: .center)
        }
    }

    @ViewBuilder
    var ProgressSubview: some View {
        if let progress = progress, progress < 1.0 {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ProgressColor(), style: .init(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .background(Circle().stroke(ProgressColor().opacity(0.2), style: .init(lineWidth: 2.5, lineCap: .round)))
                .frame(width: 15, height: 15, alignment: .center)
        }
    }

    func ProgressColor() -> Color {
        .accentColor
    }

    @ViewBuilder
    var DownloadIndicatorView: some View {
        if let download {
            DownloadIndicator(id: chapter.id, status: download)
        }
    }

    @ViewBuilder
    func ScanlatorView() -> some View {
        if let providers = chapter.providers, !providers.isEmpty {
            Text(providers.map { $0.name }.joined(separator: ", "))
                .font(.footnote)
                .fontWeight(.light)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    func LanguageView(_ lang: String) -> some View {
        if let regionCode = Locale(identifier: lang).regionCode,
           let flag = Flag(countryCode: regionCode)
        {
            Image(uiImage: flag.image(style: .none))
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 10.7)
        } else if let text = Locale.current.localizedString(forLanguageCode: lang) {
            Text(text)
        } else {
            if lang == "UNIVERSAL" {
                EmptyView()
            } else {
                Text("Unknown: \(lang)")
                    .italic()
            }
        }
    }
}

struct DownloadIndicator: View {
    var id: String
    var status: DownloadStatus
    @State var state: SDM.DownloadState?

    var size: CGFloat {
        status == .completed ? 8 : 15
    }

    @ViewBuilder
    var ACTIVE_VIEW: some View {
        ZStack {
            if let state = state {
                switch state {
                case .fetchingImages:
                    Image(systemName: "icloud.and.arrow.down")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.gray)
                        .shimmering()
                case .finalizing:
                    Image(systemName: "folder")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.green)
                        .shimmering()
                case let .downloading(progress: progress):
                    ProgressCircle(progress: progress)
                }

            } else {
                Image(systemName: "ellipsis")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
                    .shimmering()
            }
        }
    }

    var body: some View {
        ZStack {
            switch status {
            case .active:
                ACTIVE_VIEW
            case .queued, .idle:
                Image(systemName: "square.and.arrow.down")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
            case .failing:
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.red)
            case .completed:
                Circle()
                    .foregroundColor(.green)
            case .cancelled:
                Image(systemName: "x.circle")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.red)
            case .paused:
                Image(systemName: "pause.circle")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.yellow)
            }
        }
        .frame(width: size, height: size, alignment: .center)
        .opacity(0.80)
        .onReceive(SDM.shared.activeDownload) { val in
            guard let val = val, val.0 == id else {
                state = nil
                return
            }
            withAnimation {
                state = val.1
            }
        }
    }
}

struct ProgressCircle: View {
    var progress: Double
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: .init(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .background(Circle().stroke(color.opacity(0.2), style: .init(lineWidth: 2.5, lineCap: .round)))
                Image(systemName: "arrow.down")
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width * 0.4, height: proxy.size.height * 0.4, alignment: .center)
            }
        }
    }

    var completed: Bool {
        progress == 1
    }

    var color: Color {
        completed ? .green : .accentColor
    }
}
