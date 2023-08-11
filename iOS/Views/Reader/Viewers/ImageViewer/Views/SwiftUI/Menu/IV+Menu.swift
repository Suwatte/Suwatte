//
//  IV+Menu.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-07.
//

import SwiftUI


struct IVMenuView: View {
    var body: some View {
        ZStack {
            MainBody()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
                    
                    if !model.readingMode.isVertical {
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
        var body: some View {
            VStack(alignment: .leading) {
                HeaderButtons()
                Text(model.title)
                    .font(.headline)
                ActiveChapterView()
            }
            .padding(.horizontal)
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
                if var topController = KEY_WINDOW?.rootViewController {
                    while let presentedViewController = topController.presentedViewController {
                        topController = presentedViewController
                    }
                    topController.dismiss(animated: true)
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            } label: {
                Image(systemName: "xmark.circle.fill").resizable().modifier(ReaderButtonModifier())
            }
        }
        
        var SettingsButton: some View {
            Button {
                STTHelpers.triggerHaptic()
                model.toggleSettings()
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .resizable()
                    .modifier(ReaderButtonModifier())
            }
        }
    }
}


extension IVMenuView {
    struct ActiveChapterView: View {
        @EnvironmentObject var model: IVViewModel
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
                    Text(chapter.title ?? chapter.displayName)
                        .font(.subheadline)
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
                
            } label: {
                Text("\(Image(systemName: "chevron.\(asNext ? "right" : "left")"))")
                    .fontWeight(.semibold)
                    .padding()
                    .modifier(ReaderButtonModifier())
                    .foregroundColor(Color(uiColor: .systemGray))
                    .background(colorScheme == .light ? .black.opacity(0.70) : .sttGray.opacity(0.80))
                    .clipShape(Circle())
            }
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
        }
        
        
        var SliderAndButtons: some View {
            HStack {
                if model.viewerState.hasPreviousChapter {
                    ReaderNavButton(asNext: false)
                }
                ReaderSlider(value: $model.slider.current, isScrolling: $model.slider.isScrubbing, range: 0 ... 1)
                    .onChange(of: model.slider.current) { value in
                        guard model.slider.isScrubbing else { return }
                        PanelPublisher.shared.sliderPct.send(value)
                    }
                    .onChange(of: model.slider.isScrubbing) { value in
                        guard !value else { return }
                        PanelPublisher.shared.didEndScrubbing.send()
                    }
                
                if model.viewerState.hasNextChapter {
                    ReaderNavButton()
                }
            }
            .rotationEffect(.degrees(!inverted ? 0 : 180), anchor: .center)
        }
        
        var PageNumberString: String {
            "\(model.viewerState.page) of \(model.viewerState.pageCount)"
        }
        
        var bottomInset: CGFloat {
            KEY_WINDOW?.safeAreaInsets.bottom ?? 11
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

extension UIDevice {
    var hasNotch: Bool {
        let bottom = UIApplication.shared.windows[0].safeAreaInsets.bottom
        return bottom > 0
    }
}
