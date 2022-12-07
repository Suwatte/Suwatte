//
//  ProfileView+ChapterListTile.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-18.
//

import RealmSwift
import SwiftUI
import FlagKit
struct ChapterListTile: View {
    var chapter: StoredChapter
    var isCompleted: Bool
    var isNewChapter: Bool
    var progress: Double?
    var download: ICDMDownloadObject?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                DisplayNameView
                Spacer()

                IsNewView
                ProgressSubview
                DownloadIndicatorView
            }

            HStack {
                if let language = chapter.language {
                    if let regionCode = Locale(identifier: language).regionCode, let flag = Flag(countryCode: regionCode) {
                        Image(uiImage: flag.image(style: .none))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 10.7)
                    }
                    else if let text = Locale.current.localizedString(forLanguageCode: language) {
                        Text(text)
                    }
                    else {
                        Text("Unknown: \(language)")
                            .italic()
                    }
                }
                else {
                    Text("🏴‍☠️ Unknown")
                }
                
                if chapter.language != nil && !chapter.providers.isEmpty {
                    Divider()
                }

                ScanlatorView()
                Spacer()
                Text(chapter.date.timeAgoGrouped())
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(Color.gray.opacity(0.5))
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    var DisplayNameView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(chapter.displayName)
                .font(.title3)
                .foregroundColor(!isCompleted ? Color.primary : Color.gray.opacity(0.5))
            Text(chapter.title ?? chapter.chapterName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .foregroundColor(Color.gray.opacity(isCompleted ? 0.5 : 0.65))
        }
    }

    @ViewBuilder
    var IsNewView: some View {
        if isNewChapter {
            Circle()
                .foregroundColor(.blue)
                .frame(width: 10, height: 10, alignment: .center)
        }
    }

    @ViewBuilder
    var ProgressSubview: some View {
        if let progress = progress {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ProgressColor(progress), style: .init(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .background(Circle().stroke(ProgressColor(progress).opacity(0.2), style: .init(lineWidth: 2.5, lineCap: .round)))
                .frame(width: 22, height: 22, alignment: .center)
        }
    }

    func ProgressColor(_ progress: Double) -> Color {
        progress == 1.0 ? .green : .accentColor
    }

    @ViewBuilder
    var DownloadIndicatorView: some View {
        if let download = download {
            DownloadIndicator(download: download)
                .frame(width: 22, height: 22, alignment: .center)
        }
    }

    @ViewBuilder
    func ScanlatorView() -> some View {
        Text(chapter.providers.map { $0.name }.joined(separator: ", "))
            .font(.footnote)
            .fontWeight(.light)
            .lineLimit(2)
    }
}

struct DownloadIndicator: View {
    @ObservedRealmObject var download: ICDMDownloadObject
    @State var state: ICDM.ActiveDownloadState?

    @ViewBuilder
    var ACTIVE_VIEW: some View {
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
                    .foregroundColor(.green.opacity(0.5))
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

    var body: some View {
        Group {
            switch download.status {
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
                Image(systemName: "folder.circle")
                    .resizable()
                    .scaledToFit()
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

        .onReceive(ICDM.shared.activeDownloadPublisher) { val in
            guard let val = val else {
                state = nil
                return
            }

            if ICDM.shared.generateID(of: val.0) == download._id {
                withAnimation {
                    state = val.1
                }
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
