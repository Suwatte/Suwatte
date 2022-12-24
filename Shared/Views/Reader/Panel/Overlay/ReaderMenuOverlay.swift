//
//  ReaderOverlay.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-30.
//

import SwiftUI

extension ReaderView {
    struct ReaderMenuOverlay: View {
        @EnvironmentObject var model: ViewModel
        @Environment(\.presentationMode) var presentationMode
        @Environment(\.colorScheme) var colorScheme
        @Preference(\.readingLeftToRight) var readingLeftToRight
        @Preference(\.isReadingVertically) var isVertical
        @Preference(\.isPagingVertically) var isPagingVertically
        @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault

        var edges = KEY_WINDOW?.safeAreaInsets
        var body: some View {
            ZStack(alignment: Alignment(horizontal: .trailing, vertical: .top)) {
                VStack {
                    MainOverlay
                        .ignoresSafeArea()
                    Spacer()

                    if !isVertical {
                        PagedSlider()
                            .background(gradient().rotationEffect(.degrees(180)))
                    }
                }
                .ignoresSafeArea()

                if isVertical || isPagingVertically {
                    VStack {
                        Spacer()
                        WebtoonSlider()
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .statusBar(hidden: !model.menuControl.menu)
            .animation(.default, value: model.activeChapter)
            .accentColor(accentColor)
            .tint(accentColor)
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
                    Image(systemName: "chevron.down").imageScale(.medium)
                }
                .contentShape(Rectangle())
                .padding(.trailing, 7)
            }
            .buttonStyle(.plain)
        }

        // MARK: CORE Overlay

        var MainOverlay: some View {
            VStack {
                VStack(alignment: .leading, spacing: 5) {
                    HeaderButtons
                        .padding(.top, edges?.top != nil && edges!.top != 0 ? edges!.top + 10 : nil)
                        .padding(.bottom, 7)
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
                .background(gradient())
            }
        }

        // MARK: Quick Actions View

        var QuickActionsButton: some View {
            HStack(spacing: 17) {
                Button {
                    model.menuControl.toggleComments()
                } label: {
                    Image(systemName: "text.bubble")
                        .resizable()
                        .modifier(ReaderButtonModifier())
                        .foregroundColor(defaultFGColor)
                }
                //                .sheet(isPresented: $viewModel.config.displayComments, content: {
                //                    Text("Comments Sheet")
                //                })
            }
        }

        // MARK: Gradient Overlay

        var defaultFGColor: Color {
            colorScheme == .dark ? .white : .black
        }

        var grad: Gradient {
            let color: Color = colorScheme == .dark ? .black : .white
            //
            return .init(stops: [
                .init(color: color, location: 0.0),
                .init(color: color.opacity(0.75), location: 0.75),
                .init(color: color.opacity(0.0), location: 1.0),

            ])
        }

        func gradient() -> some View {
            LinearGradient(gradient: grad, startPoint: .top, endPoint: .bottom)
                .onTapGesture {
                    withAnimation {
                        model.menuControl.toggleMenu()
                    }
                }
        }

        // MARK: Header Buttons

        var HeaderButtons: some View {
            HStack {
                Button {
                    //                    presentationMode.wrappedValue.dismiss()
                    if var topController = KEY_WINDOW?.rootViewController {
                        while let presentedViewController = topController.presentedViewController {
                            topController = presentedViewController
                        }
                        topController.dismiss(animated: true)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill").resizable().modifier(ReaderButtonModifier())
                }
                Spacer()
                Button {
                    model.menuControl.toggleSettings()
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .resizable()
                        .modifier(ReaderButtonModifier())
                }
            }
        }
    }
}

// MARK: Webtoon Slider

extension ReaderView.ReaderMenuOverlay {
    struct WebtoonSlider: View {
        @EnvironmentObject var model: ReaderView.ViewModel
        var body: some View {
            VStack(alignment: .center) {
                PrevButton()
                    .rotationEffect(.degrees(90))
                OverlaySlider
                NextButton()
                    .rotationEffect(.degrees(90))
            }
            .padding()
        }

        var OverlaySlider: some View {
            ZStack(alignment: Alignment(horizontal: .center, vertical: .center)) {
                RoundedRectangle(cornerRadius: 100)
                    .foregroundColor(.sttGray)
                    .frame(width: 25)

                if model.slider.max > model.slider.min {
                    ReaderView.Sliders.VerticalSlider(value: $model.slider.current, isScrolling: $model.slider.isScrubbing, range: model.slider.min ... model.slider.max)
                        .padding(.vertical, 6)
                }
            }
            .frame(height: UIScreen.main.bounds.height * 0.45)
        }
    }
}

extension ReaderView.ReaderMenuOverlay {
    struct NextButton: View {
        @EnvironmentObject var model: ReaderView.ViewModel

        var body: some View {
            Button(action: { if model.NextChapter != nil { model.resetToChapter(model.NextChapter!) } },
                   label: {
                       Text("\(Image(systemName: "chevron.right"))")
                           .fontWeight(.semibold)
                           .modifier(ReaderButtonModifier())
                           .background(Color.sttGray)
                           .clipShape(Circle())
                           .foregroundColor(.gray)
                   })
                   .disabled(model.NextChapter == nil)
        }
    }

    struct PrevButton: View {
        @EnvironmentObject var model: ReaderView.ViewModel

        var body: some View {
            Button(action: { if model.PreviousChapter != nil { model.resetToChapter(model.PreviousChapter!) } },
                   label: {
                       Text("\(Image(systemName: "chevron.left"))")
                           .fontWeight(.bold)
                           .modifier(ReaderButtonModifier())
                           .background(Color.sttGray)
                           .clipShape(Circle())
                           .foregroundColor(.gray)
                   })
                   .disabled(model.PreviousChapter == nil)
        }
    }

    struct PagedSlider: View {
        @EnvironmentObject var model: ReaderView.ViewModel
        @AppStorage(STTKeys.PagedDirection) var readingLeftToRight = true
        @Preference(\.isPagingVertically) var isPagingVertically

        var edges = KEY_WINDOW?.safeAreaInsets

        var READY: Bool {
            model.activeChapter.data.LOADED && !(model.activeChapter.pages?.isEmpty ?? false)
        }

        var body: some View {
            VStack {
                HStack {
                    PrevButton()
                    OverlaySlider
                        .opacity(READY ? 1 : 0)
                    NextButton()
                }
                .buttonStyle(.plain)
                .rotationEffect(.degrees(readingLeftToRight ? 0 : 180), anchor: .center)
                .opacity(isPagingVertically ? 0 : 1)

                if let index = model.activeChapter.requestedPageIndex, let pageCount = model.activeChapter.pages?.last?.number {
                    Text("Page \(model.scrubbingPageNumber != nil ? model.scrubbingPageNumber! : index + 1) of \(pageCount)")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .padding(.bottom, edges?.bottom)
                        .opacity(READY ? 1 : 0)
                }
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

extension ReaderView {
    struct AutoScrollOverlay: View {
        @EnvironmentObject var model: ReaderView.ViewModel
        var edges = KEY_WINDOW?.safeAreaInsets

        var body: some View {
            ZStack {
                Button {
                    model.verticalTimerPublisher.send()
                } label: {
                    Image(systemName: model.autoplayEnabled ? "pause.circle" : "play.circle")
                        .resizable()
                        .modifier(ReaderButtonModifier())
                        .background(Color.sttGray)
                        .clipShape(Circle())
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 7 + (edges?.bottom ?? 0))
                .padding(.horizontal)
                .opacity(0.85)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
}
