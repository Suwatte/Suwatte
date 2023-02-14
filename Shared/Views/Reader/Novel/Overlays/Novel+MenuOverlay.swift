//
//  Novel+MenuOverlay.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-31.
//

import SwiftUI

extension NovelReaderView {
    struct MenuOverlay: View {
        @EnvironmentObject var model: ViewModel
        @Environment(\.presentationMode) var presentationMode
        @Environment(\.colorScheme) var colorScheme
        @Preference(\.novelUseVertical) var isVertical
        var edges = KEY_WINDOW?.safeAreaInsets

        // Child Sizes
        @State var footerSize = CGSize(width: 0, height: 0)
        @State var headerSize = CGSize(width: 0, height: 300)
        var body: some View {
            ZStack(alignment: Alignment(horizontal: .trailing, vertical: .top)) {
                VStack {
                    MainOverlay
                        .modifier(ViewSizeReader(size: $headerSize))
                    Spacer()
                    PagedSlider()
                        .modifier(ViewSizeReader(size: $footerSize))
                        .background(gradient(color: colors.reversed()))
                        .opacity(isVertical ? 0 : 1)
                }
            }
            .animation(.default, value: model.currentSectionPageNumber)
        }
    }
}

// MARK: Colors

extension NovelReaderView.MenuOverlay {
    var colors: [Color] {
        let color: Color = colorScheme == .dark ? .black : .white
        //
        return [color, color.opacity(0.9), color.opacity(0.8), color.opacity(0.5), .clear]
    }

    func gradient(color: [Color]) -> some View {
        LinearGradient(gradient: Gradient(colors: color), startPoint: .top, endPoint: .bottom)
            .onTapGesture {
                withAnimation {
                    model.menuControl.toggleMenu()
                }
            }
    }

    var defaultFGColor: Color {
        colorScheme == .dark ? .white : .black
    }
}

// MARK: CORE Overlay

extension NovelReaderView.MenuOverlay {
    var MainOverlay: some View {
        VStack {
            VStack(alignment: .leading, spacing: 5) {
                HeaderButtons
                    .padding(.top, edges?.top != nil && edges!.top != 0 ? edges!.top + 5 : nil)
                    .padding(.bottom)
                Text(model.title.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.headline)
                HStack {
                    ActiveChapterTitleView
                    Spacer()
//                        QuickActionsButton
                }
                .padding(.bottom, 65)
            }
            .padding(.leading, 5)
            .padding(.horizontal)
            .background(gradient(color: colors))
        }
    }

    // MARK: Chapter Title Display

    @ViewBuilder
    var ActiveChapterTitleView: some View {
        Button {
            model.menuControl.toggleChapterList()
        }
            label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(model.activeChapter.chapter.displayName)
                        .font(.headline)
                    Text(model.activeChapter.chapter.title ?? model.activeChapter.chapter.displayName)
                        .font(.subheadline)
                }
                Image(systemName: "chevron.down")
                    .imageScale(.medium)
            }
        }
        .buttonStyle(.plain)
    }

    var HeaderButtons: some View {
        HStack {
            Button {
//
                if var topController = KEY_WINDOW?.rootViewController {
                    while let presentedViewController = topController.presentedViewController {
                        topController = presentedViewController
                    }
                    withAnimation {
                        topController.dismiss(animated: true)
                    }

                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .modifier(ReaderButtonModifier())
            }
            Spacer()
            Button {
                model.menuControl.toggleSettings()
            } label: {
                Image(systemName: "textformat.size")
                    .resizable()
                    .modifier(ReaderButtonModifier())
            }
        }
    }
}

// MARK: Paged Slider

extension NovelReaderView.MenuOverlay {
    struct PagedSlider: View {
        @EnvironmentObject var model: NovelReaderView.ViewModel
        var edges = KEY_WINDOW?.safeAreaInsets

        var READY: Bool {
            model.activeChapter.data.LOADED && model.getPageCount() != 0
        }

        var activeChapterIndex: Int {
            model.readerChapterList.firstIndex(where: { $0 === model.activeChapter }) ?? -1
        }

        var body: some View {
            VStack {
                OverlaySlider
                    .opacity(READY ? 1 : 0)
                    .buttonStyle(.plain)

                Text("\(model.scrubbingPageNumber ?? (model.currentSectionPageNumber)) / \(model.getPageCount())")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding(.bottom, edges?.bottom)
                    .opacity(READY ? 1 : 0)
            }
            .padding()
        }

        // MARK: Horizontal Slider

        @ViewBuilder
        var OverlaySlider: some View {
            ZStack(alignment: Alignment(horizontal: .center, vertical: .center)) {
                RoundedRectangle(cornerRadius: 100)
                    .foregroundColor(.sttGray)
                    .frame(height: 25)

                if model.slider.min < model.slider.max {
                    ReaderView.Sliders.HorizontalSlider(value: $model.slider.current, isScrolling: $model.slider.isScrubbing, range: model.slider.min ... model.slider.max)
                        .padding(.horizontal, 7)
                        .onChange(of: model.slider.isScrubbing) { val in
                            if !val {
                                model.scrubEndPublisher.send()
                            }
                        }
                } else {
                    Text("-")
                }
            }
        }
    }
}
