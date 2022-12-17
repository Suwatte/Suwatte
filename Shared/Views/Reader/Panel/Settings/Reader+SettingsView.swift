//
//  Reader+SettingsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-31.
//

import SwiftUI

extension ReaderView {
    struct SettingsView: View {
        // AppStorage
        @AppStorage(STTKeys.EnableOverlay) var enableOverlay = false
        @AppStorage(STTKeys.TapSidesToNavigate) var tapToNavigate = false
        @AppStorage(STTKeys.OverlayColor) var overlayColor: Color = .black
        @AppStorage(STTKeys.BackgroundColor) var backgroundColor = Color.primary
        @AppStorage(STTKeys.UseSystemBG) var useSystemBG = true
        @AppStorage(STTKeys.PagedNavigator) var pagedNavigator = ReaderNavigation.Modes.standard
        @AppStorage(STTKeys.VerticalNavigator) var verticalNavigator = ReaderNavigation.Modes.lNav
        @AppStorage(STTKeys.ReaderFilterBlendMode) var readerBlendMode = ReaderBlendMode.normal
        @AppStorage(STTKeys.ReaderGrayScale) var useGrayscale = false
        @AppStorage(STTKeys.ReaderColorInvert) var useColorInvert = false

        // Preference Publisher
        @Preference(\.readingLeftToRight) var readingLeftToRight
        @Preference(\.forceTransitions) var forceTransitions
        @Preference(\.imageInteractions) var imageInteractions
        @Preference(\.downsampleImages) var downsampleImages
        @Preference(\.cropWhiteSpaces) var cropWhiteSpaces
        @Preference(\.displayNavOverlay) var displayNavOverlay
        @Preference(\.isReadingVertically) var isVertical
        @Preference(\.isDoublePagedEnabled) var isDoublePaged
        @Preference(\.invertTapSidesToNavigate) var invertTapSidesToNavigate
        @Preference(\.VerticalPagePadding) var verticalPagePadding
        var body: some View {
            List {
                // Reading Mode
                Section {
                    // Viewer
                    Picker("Viewer", selection: $isVertical) {
                        Text("Paged").tag(false)
                        Text("Vertical").tag(true)
                    }
                    .pickerStyle(.segmented)

                } header: {
                    Text("Reading Mode")
                }

                // Reading Direction
                if !isVertical {
                    Section {
                        Picker("Reading Direction", selection: $readingLeftToRight) {
                            Text("Left To Right (Comic)")
                                .tag(true)
                            Text("Right to Left (Manga)")
                                .tag(false)
                        }.pickerStyle(.segmented)
                        Toggle("Double Paged", isOn: $isDoublePaged)
                    } header: {
                        Text("Reading Direction")
                    }
                } else {
                    Section {
                        Toggle("Page Padding", isOn: $verticalPagePadding)
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

                // Images
                Section {
                    Toggle("Image Context Actions", isOn: $imageInteractions)
                    Toggle("Downsample Images", isOn: $downsampleImages)

                    if !isVertical {
                        Toggle("Crop Whitespace", isOn: $cropWhiteSpaces)
                    }
                } header: {
                    Text("Image Options")
                } footer: {
                    if !isVertical {
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
                            ForEach(ReaderBlendMode.allCases, id: \.rawValue) {
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
            .animation(.default, value: enableOverlay)
            .animation(.default, value: useSystemBG)
            .animation(.default, value: tapToNavigate)
            .animation(.default, value: isVertical)
        }
    }
}

enum ReaderBlendMode : Int, CaseIterable {
    case normal, screen, multiply
    
    var description : String {
        switch self {
            case .multiply:
                return "Multiply"
            case .normal:
                return "Normal"
            case .screen:
                return "Screen"
        }
    }
    
    var blendMode: BlendMode {
        switch self {
            case .normal:
                return .normal
            case .screen:
                return .screen
            case .multiply:
                return .multiply
        }
    }
}
