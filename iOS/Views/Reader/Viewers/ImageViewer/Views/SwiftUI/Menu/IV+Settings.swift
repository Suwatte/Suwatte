//
//  IV+Settings.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-09.
//

import SwiftUI

struct IVSettingsView: View {
    // AppStorage
    @AppStorage(STTKeys.OverlayColor) var overlayColor: Color = .black
    @AppStorage(STTKeys.BackgroundColor) var backgroundColor = Color.primary
    @AppStorage(STTKeys.PagedNavigator) var pagedNavigator = ReaderNavigation.Modes.standard
    @AppStorage(STTKeys.VerticalNavigator) var verticalNavigator = ReaderNavigation.Modes.lNav
    @AppStorage(STTKeys.ReaderFilterBlendMode) var readerBlendMode = STTBlendMode.normal
    @AppStorage(STTKeys.ReaderGrayScale) var useGrayscale = false
    @AppStorage(STTKeys.ReaderColorInvert) var useColorInvert = false
    // Preference Publisher
    @Preference(\.enableOverlay) var enableOverlay
    @Preference(\.useSystemBG) var useSystemBG
    @Preference(\.verticalAutoScroll) var verticalAutoScroll
    @Preference(\.tapSidesToNavigate) var tapToNavigate
    @Preference(\.verticalAutoScrollSpeed) var autoScrollSpeed
    @Preference(\.imageInteractions) var imageInteractions
    @Preference(\.downsampleImages) var downsampleImages
    @Preference(\.cropWhiteSpaces) var cropWhiteSpaces
    @Preference(\.displayNavOverlay) var displayNavOverlay
    @Preference(\.isDoublePagedEnabled) var isDoublePaged
    @Preference(\.invertTapSidesToNavigate) var invertTapSidesToNavigate
    @Preference(\.VerticalPagePadding) var verticalPagePadding
    @Preference(\.imageScaleType) var imageScaleType
    @Preference(\.usePillarBox) var usePillarBox
    @Preference(\.pillarBoxPCT) var pillarBoxPCT

    @Preference(\.enableReaderHaptics) var readerHaptics
    @Preference(\.forceTransitions) var forceTransitions
    @Preference(\.splitWidePages) var splitWidePages
    @Preference(\.verticalPagePaddingAmount) var pagePaddingAmount
    @Preference(\.markFirstAsSingle) var markFirstAsSingle
    private let autoScrollRange: ClosedRange<Double> = 2.5 ... 30
    private let pillarBoxRange: ClosedRange<Double> = 0.15 ... 1.0
    @State var holdingAutoScrollBinding: Double = 0.0
    @State var holdingPillarBoxPCT: Double = 0.0
    @EnvironmentObject var model: IVViewModel

    var body: some View {
        SmartNavigationView {
            Form {
                // Reading Mode
                Section {
                    // Viewer
                    ModeSelectorView()

                } header: {
                    Text("Mode")
                }

                // Reading Direction
                if model.readingMode.isHorizontalPager {
                    Section {
                        Toggle("Double Paged", isOn: $isDoublePaged)
                            .onChange(of: isDoublePaged) { _ in
                                model.setIsDoublePaged(isDoublePaged: isDoublePaged)
                                model.producePendingState()
                            }

                        if isDoublePaged {
                            Toggle("Always Isolate First Panel", isOn: $markFirstAsSingle)
                        }
                    } header: {
                        Text("Paging Options")
                    }
                }

                Section {
                    ScrollbarPositionSelectorView()
                    if model.readingMode.isVertical && !model.scrollbarPosition.isVertical(model.readingMode.isVertical) {
                        BottomScrollbarDirectionSelectorView()
                    }
                } header: {
                    Text("Scrollbar Position")
                }

                if model.readingMode == .VERTICAL {
                    Section {
                        Toggle("AutoScroll", isOn: $verticalAutoScroll)
                        if verticalAutoScroll {
                            let bridge = Binding<Double>(get: {
                                autoScrollRange.upperBound - holdingAutoScrollBinding + autoScrollRange.lowerBound
                            }, set: {
                                holdingAutoScrollBinding = autoScrollRange.upperBound - $0 + autoScrollRange.lowerBound
                            })
                            VStack(alignment: .leading) {
                                Text("Scroll Speed")
                                HStack {
                                    Image(systemName: "tortoise")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 25)
                                        .foregroundColor(.gray)

                                    Slider(value: bridge, in: autoScrollRange) { editing in
                                        if editing { return }
                                        autoScrollSpeed = holdingAutoScrollBinding
                                    }
                                    Image(systemName: "hare")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 25)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    } header: {
                        Text("AutoScroll")
                    } footer: {
                        if verticalAutoScroll {
                            Text("Will scroll through one screens height in roughly \(holdingAutoScrollBinding.clean) seconds.")
                        }
                    }

                    Section {
                        Toggle("Enabled Pillarbox", isOn: $usePillarBox)
                        if usePillarBox {
                            VStack(alignment: .leading) {
                                Text("Amount")
                                Slider(value: $holdingPillarBoxPCT, in: pillarBoxRange) { editing in
                                    if editing { return }
                                    pillarBoxPCT = holdingPillarBoxPCT
                                }
                            }
                        }
                    } header: {
                        Text("Pillarbox / Horizontal Padding")
                    } footer: {
                        if usePillarBox {
                            Text("Images will be sized to fit roughly \((holdingPillarBoxPCT * 100).clean)% of the screen's width.")
                        }
                    }

                    Section {
                        Toggle("Enable Padding", isOn: $verticalPagePadding)
                        if verticalPagePadding {
                            Stepper(value: $pagePaddingAmount, in: 5 ... 50, step: 5) {
                                FieldLabel(primary: "Amount",
                                           secondary: pagePaddingAmount.description)
                            }
                        }
                    } header: {
                        Text("Page Padding")
                    }
                }

                Section {
                    Toggle("Tap Sides To Navigate", isOn: $tapToNavigate)

                    if tapToNavigate {
                        Toggle("Invert Navigation Regions", isOn: $invertTapSidesToNavigate)

                        Toggle("Display Guide", isOn: $displayNavOverlay)

                        Picker("Navigation Layout", selection: model.readingMode.isVertical ? $verticalNavigator : $pagedNavigator) {
                            ForEach(ReaderNavigation.Modes.allCases) { entry in
                                Text(entry.mode.title)
                                    .tag(entry)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                } header: {
                    Text("Navigation")
                }

                Section {
                    Toggle("Haptic Feedback", isOn: $readerHaptics)
                    Toggle("Transition Pages", isOn: $forceTransitions)
                } header: {
                    Text("Miscellaneous")
                } footer: {
                    Text("Transition pages will not appear when chapters have less than 10 pages.")
                }

                // Images
                Section {
                    Toggle("Context Actions", isOn: $imageInteractions)
                    if model.readingMode.isHorizontalPager {
                        Toggle("Split Wide Pages", isOn: $splitWidePages)
                            .onChange(of: splitWidePages) { _ in
                                PanelPublisher.shared.didChangeSplitMode.send()
                            }
                    }
                    if model.readingMode.isHorizontalPager || model.readingMode == .PAGED_VERTICAL {
                        Picker("Scale Type", selection: $imageScaleType) {
                            ForEach(ImageScaleOption.allCases, id: \.rawValue) {
                                Text($0.description)
                                    .tag($0)
                            }
                        }
                    }

                    Toggle("Downsample Image", isOn: $downsampleImages)
                    if model.readingMode != .VERTICAL {
                        Toggle("Crop Whitespace", isOn: $cropWhiteSpaces)
                    }
                } header: {
                    Text("Image Options")
                } footer: {
                    if model.readingMode != .VERTICAL {
                        Text("Removes excess white border surrounding panels.")
                    }
                }

                // Background
                Section {
                    Toggle("Use System Background", isOn: $useSystemBG)

                    if !useSystemBG {
                        ColorPicker("Background Color", selection: $backgroundColor)
                    }
                } header: {
                    Text("Background")
                }

                // Overlay
                Section {
                    Toggle("Custom Overlay", isOn: $enableOverlay)
                    if enableOverlay {
                        ColorPicker("Color & Opacity", selection: $overlayColor)
                        Picker("Blend Mode", selection: $readerBlendMode) {
                            ForEach(STTBlendMode.allCases, id: \.rawValue) {
                                Text($0.description)
                                    .tag($0)
                            }
                        }
                    }

                } header: {
                    Text("Overlay")
                }
                Section {
                    Toggle("Grayscale", isOn: $useGrayscale)
                    Toggle("Color Invert", isOn: $useColorInvert)
                } header: {
                    Text("Filters")
                }
            }
            .onAppear {
                holdingPillarBoxPCT = pillarBoxPCT
                holdingAutoScrollBinding = autoScrollSpeed
            }
            .animation(.default, value: enableOverlay)
            .animation(.default, value: useSystemBG)
            .animation(.default, value: tapToNavigate)
            .animation(.default, value: model.readingMode)
            .animation(.default, value: verticalAutoScroll)
            .animation(.default, value: usePillarBox)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .closeButton()
            .task {
                model.hideMenu()
            }
        }
    }
}

extension IVSettingsView {
    struct ModeSelectorView: View {
        @AppStorage(STTKeys.ReaderType) var mode = ReadingMode.PAGED_COMIC
        @EnvironmentObject var model: IVViewModel
        @Preference(\.currentReadingMode) var readingMode

        var body: some View {
            Picker("Reading Mode", selection: $readingMode) {
                ForEach(ReadingMode.PanelCases(), id: \.rawValue) {
                    Text($0.description)
                        .tag($0)
                }
            }
            .onChange(of: readingMode, perform: updateReadingMode)
        }

        func updateReadingMode(_ value: ReadingMode) {
            model.producePendingState()
            model.readingMode = value
            if value.isHorizontalPager {
                PanelPublisher.shared.didChangeHorizontalDirection.send()
            }

            // Update on a per-comic basis
            let id = model.viewerState.chapter.STTContentIdentifier
            let container = UserDefaults.standard
            let key = STTKeys.ReaderType + "%%" + id
            container.setValue(value.rawValue, forKey: key)
        }
    }

    struct ScrollbarPositionSelectorView: View {
        @EnvironmentObject var model: IVViewModel

        var body: some View {
            Picker("Position", selection: $model.scrollbarPosition) {
                ForEach(ReaderScrollbarPosition.PositionCases(), id: \.rawValue) {
                    Text($0.description)
                        .tag($0)
                }
            }
            .onChange(of: model.scrollbarPosition, perform: updateScrollbarPosition)
        }

        func updateScrollbarPosition(_ value: ReaderScrollbarPosition) {
            model.producePendingState()
            model.scrollbarPosition = value

            // Update on a per-comic basis
            let id = model.viewerState.chapter.STTContentIdentifier
            let container = UserDefaults.standard
            let key = STTKeys.ReaderScrollbarPosition + "%%" + id
            container.setValue(value.rawValue, forKey: key)
        }
    }

    struct BottomScrollbarDirectionSelectorView: View {
        @EnvironmentObject var model: IVViewModel

        var body: some View {
            Picker("Direction", selection: $model.bottomScrollbarDirection) {
                ForEach(ReaderBottomScrollbarDirection.DirectionCases(), id: \.rawValue) {
                    Text($0.description)
                        .tag($0)
                }
            }
            .onChange(of: model.bottomScrollbarDirection, perform: updateBottomScrollbarDirection)
        }

        func updateBottomScrollbarDirection(_ value: ReaderBottomScrollbarDirection) {
            model.producePendingState()
            model.bottomScrollbarDirection = value

            // Update on a per-comic basis
            let id = model.viewerState.chapter.STTContentIdentifier
            let container = UserDefaults.standard
            let key = STTKeys.ReaderBottomScrollbarDirection + "%%" + id
            container.setValue(value.rawValue, forKey: key)
        }
    }
}
