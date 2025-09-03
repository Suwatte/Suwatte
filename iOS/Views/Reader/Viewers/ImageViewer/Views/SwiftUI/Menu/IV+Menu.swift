//
//  IV+Menu.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-07.
//

import SwiftUI

struct IVMenuView: View {
    @EnvironmentObject var model: IVViewModel
    var body: some View {
        ZStack(alignment: .center) {
            MainBody()
            if model.scrollbarPosition.isVertical(model.readingMode.isVertical) {
                GeometryReader { proxy in
                    ZStack(alignment: .center) {
                        VerticalSliderView()
                            .transition(.move(edge: .trailing))
                            .frame(width: proxy.size.width,
                                   height: proxy.size.height * 0.60,
                                   alignment: Alignment(horizontal: model.scrollbarPosition == .LEFT ? .leading : .trailing, vertical: .center))
                    }
                    .frame(height: proxy.size.height)
                }
                .frame(alignment: .center)
            }
        }
        .animation(.default, value: model.control)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onChange(of: model.slider.current) { value in
            guard model.slider.isScrubbing else { return }
            PanelPublisher.shared.sliderPct.send(value)
        }
        .onChange(of: model.slider.isScrubbing) { value in
            guard !value else { return }
            PanelPublisher.shared.didEndScrubbing.send()
        }
    }
}

extension IVMenuView {
    struct MainBody: View {
        @EnvironmentObject var model: IVViewModel
        @Environment(\.presentationMode) var presentationMode
        @Preference(\.accentColor) var accentColor

        var body: some View {
            GeometryReader { proxy in
                VStack(alignment: .center) {
                    HeaderView()
                        .frame(height: proxy.size.height * 0.40, alignment: .top)
                    Spacer()

                    if !model.scrollbarPosition.isVertical(model.readingMode.isVertical) {
                        BottomView()
                            .frame(height: proxy.size.height * 0.225, alignment: .bottom)
                    }
                }
            }
        }
    }
}

extension IVMenuView {
    struct GradientModifier: ViewModifier {
        @EnvironmentObject var model: IVViewModel
        @Environment(\.colorScheme) var colorScheme
        var rotate = false
        func body(content: Content) -> some View {
            content
                .background(MainView)
        }

        private var gradient: Gradient {
            let color: Color = colorScheme == .dark ? .black : .white
            return .init(stops: [
                .init(color: color, location: 0.0),
                .init(color: color.opacity(0.0), location: 1.0),

            ])
        }

        private var MainView: some View {
            LinearGradient(gradient: gradient, startPoint: .top, endPoint: .bottom)
                .rotationEffect(rotate ? .degrees(180) : .zero)
                .allowsHitTesting(false)
        }
    }

    struct HeaderView: View {
        @EnvironmentObject var model: IVViewModel
        @Environment(\.colorScheme) var colorScheme
        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                HeaderButtons()
                Text(model.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .shadow(radius: colorScheme == .dark ? 1.5 : 0)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .frame(alignment: .leadingLastTextBaseline)
                    .padding(.horizontal)

                ActiveChapterView()
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .modifier(GradientModifier())
        }
    }

    struct HeaderButtons: View {
        @Environment(\.presentationMode) var presentationMode
        @EnvironmentObject var model: IVViewModel

        var topInset: CGFloat {
            (UIDevice.current.hasNotch ? 44 : 24) + 5
        }

        var body: some View {
            HStack {
                CloseButton
                Spacer()
                SettingsButton
            }
            .padding(.top, topInset)
        }

        var CloseButton: some View {
            Button {
                STTHelpers.triggerHaptic()
                let window = getKeyWindow()
                if var topController = window?.rootViewController {
                    while let presentedViewController = topController.presentedViewController {
                        topController = presentedViewController
                    }
                    topController.dismiss(animated: true)
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .modifier(ReaderButtonModifier())
                    .contentShape(Circle())
                    .padding(.horizontal)
            }
        }

        var SettingsButton: some View {
            Button {
                STTHelpers.triggerHaptic()
                model.toggleSettings()
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .modifier(ReaderButtonModifier())
                    .contentShape(Circle())
                    .padding(.horizontal)
            }
        }
    }
}

extension IVMenuView {
    struct ActiveChapterView: View {
        @EnvironmentObject var model: IVViewModel
        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            Button {
                open()
            } label: {
                Wrapper
            }
            .buttonStyle(.plain)
            .disabled(model.viewerState == .placeholder)
        }

        @ViewBuilder
        var Wrapper: some View {
            Group {
                LabelView(model.viewerState.chapter)
            }
            .contentShape(Rectangle())
            .padding(.trailing, 7)
        }

        func LabelView(_ chapter: ThreadSafeChapter) -> some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(chapter.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .shadow(radius: colorScheme == .dark ? 1.5 : 0)
                    Text(chapter.title ?? chapter.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .shadow(radius: colorScheme == .dark ? 1.5 : 0)
                }
                Image(systemName: "chevron.down").imageScale(.medium)
                    .opacity(model.chapterCount != 1 ? 1 : 0)
            }
        }

        func open() {
            guard model.chapterCount > 1 else { return }
            STTHelpers.triggerHaptic()
            model.toggleChapterList()
        }
    }
}

extension IVMenuView {
    struct ReaderNavButton: View {
        @EnvironmentObject var model: IVViewModel
        var asNext: Bool = true
        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            Button {
                STTHelpers.triggerHaptic()
                Task {
                    await navigate()
                }
            } label: {
                Image(systemName: "chevron.\(asNext ? "right" : "left").circle.fill")
                    .resizable()
                    .scaledToFit()
                    .modifier(ReaderButtonModifier())
                    .clipShape(Circle())
            }
        }

        func navigate() async {
            let current = model.viewerState.chapter
            let cache = model.dataCache
            let chapter = await asNext ? cache.getChapter(after: current) : cache.getChapter(before: current)
            guard let chapter else {
                return
            }
            await model.resetToChapter(chapter)
        }
    }

    struct BottomView: View {
        @EnvironmentObject var model: IVViewModel

        var body: some View {
            VStack {
                SliderAndButtons
                PageNumber
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .modifier(GradientModifier(rotate: true))
        }

        var inverted: Bool {
            model.readingMode.isInverted
                || (model.readingMode.isVertical
                    && !model.scrollbarPosition.isVertical(model.readingMode.isVertical)
                    && model.bottomScrollbarDirection == .LEFT)
        }

        var SliderAndButtons: some View {
            HStack {
                if model.viewerState.hasPreviousChapter {
                    ReaderNavButton(asNext: false)
                }
                ReaderHSlider(value: $model.slider.current, isScrolling: $model.slider.isScrubbing, range: 0 ... 1, barSize: model.scrollbarWidth)

                if model.viewerState.hasNextChapter {
                    ReaderNavButton()
                }
            }
            .rotationEffect(.degrees(!inverted ? 0 : 180), anchor: .center)
        }

        var PageNumberString: String {
            "\(model.viewerState.page) of \(model.viewerState.pageCount)"
        }

        @MainActor
        private var edges: UIEdgeInsets? {
            let window = getKeyWindow()
            return window?.safeAreaInsets
        }

        var bottomInset: CGFloat {
            edges?.bottom ?? 11
        }

        var PageNumber: some View {
            Text(PageNumberString)
                .font(.footnote.italic())
                .fontWeight(.light)
                .foregroundColor(.gray)
                .padding(.bottom, bottomInset)
                .showIf(model.viewerState != .placeholder)
                .transition(.opacity)
        }
    }
}

extension IVMenuView {
    struct VerticalSliderView: View {
        @EnvironmentObject var model: IVViewModel

        var body: some View {
            VStack(alignment: .center) {
                if model.viewerState.hasPreviousChapter {
                    ReaderNavButton(asNext: false)
                        .rotationEffect(.degrees(90))
                }
                ReaderVSlider(value: $model.slider.current, isScrolling: $model.slider.isScrubbing, range: 0 ... 1, barSize: model.scrollbarWidth)

                if model.viewerState.hasNextChapter {
                    ReaderNavButton()
                        .rotationEffect(.degrees(90))
                }
            }
            .padding()
        }
    }
}
