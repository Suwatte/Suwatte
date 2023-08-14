//
//  IV+Settings.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-09.
//

import SwiftUI



struct IVSettingsView: View {
    // AppStorage
    @AppStorage(STTKeys.EnableOverlay) var enableOverlay = false
    @AppStorage(STTKeys.TapSidesToNavigate) var tapToNavigate = false
    @AppStorage(STTKeys.OverlayColor) var overlayColor: Color = .black
    @AppStorage(STTKeys.BackgroundColor) var backgroundColor = Color.primary
    @AppStorage(STTKeys.UseSystemBG) var useSystemBG = true
    @AppStorage(STTKeys.PagedNavigator) var pagedNavigator = ReaderNavigation.Modes.standard
    @AppStorage(STTKeys.VerticalNavigator) var verticalNavigator = ReaderNavigation.Modes.lNav
    @AppStorage(STTKeys.ReaderFilterBlendMode) var readerBlendMode = STTBlendMode.normal
    @AppStorage(STTKeys.ReaderGrayScale) var useGrayscale = false
    @AppStorage(STTKeys.ReaderColorInvert) var useColorInvert = false
    @AppStorage(STTKeys.VerticalAutoScroll) var verticalAutoScroll = false
    // Preference Publisher
    @Preference(\.verticalAutoScrollSpeed) var autoScrollSpeed
    @Preference(\.readingLeftToRight) var readingLeftToRight
    @Preference(\.imageInteractions) var imageInteractions
    @Preference(\.downsampleImages) var downsampleImages
    @Preference(\.cropWhiteSpaces) var cropWhiteSpaces
    @Preference(\.displayNavOverlay) var displayNavOverlay
    @Preference(\.isReadingVertically) var isVertical
    @Preference(\.isDoublePagedEnabled) var isDoublePaged
    @Preference(\.invertTapSidesToNavigate) var invertTapSidesToNavigate
    @Preference(\.VerticalPagePadding) var verticalPagePadding
    @Preference(\.imageScaleType) var imageScaleType
    @Preference(\.usePillarBox) var usePillarBox
    @Preference(\.pillarBoxPCT) var pillarBoxPCT

    @Preference(\.enableReaderHaptics) var readerHaptics
    @Preference(\.forceTransitions) var forceTransitions
    @Preference(\.splitWidePages) var splitWidePages
    private let autoScrollRange: ClosedRange<Double> = 2.5 ... 30
    private let pillarBoxRange: ClosedRange<Double> = 0.15 ... 1.0
    @State var holdingAutoScrollBinding: Double = 0.0
    @State var holdingPillarBoxPCT: Double = 0.0
    @EnvironmentObject var model: IVViewModel

    var body: some View {
        NavigationView {
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
                    } header: {
                        Text("Paging Options")
                    }
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
                }

                Section {
                    Toggle("Tap Sides To Navigate", isOn: $tapToNavigate)

                    if tapToNavigate {
                        Toggle("Invert Navigation Regions", isOn: $invertTapSidesToNavigate)

                        Toggle("Display Guide", isOn: $displayNavOverlay)

                        Picker("Navigation Layout", selection: isVertical ? $verticalNavigator : $pagedNavigator) {
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
            .onChange(of: readingMode, perform: { v in
                model.producePendingState()
                model.readingMode = v
                if v.isHorizontalPager {
                    PanelPublisher.shared.didChangeHorizontalDirection.send()
                }
            })
        }
    }

}
