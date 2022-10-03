//
//  Novel+SettingsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-30.
//

import SwiftUI

extension NovelReaderView {
    struct SettingsView: View {
        @Preference(\.novelFontSize) var fontSize
        @Preference(\.novelUseVertical) var useVertical
        @Preference(\.novelOrientationLock) var orientationLock
        @Preference(\.novelUseDoublePaged) var useDoublePaged
        @Preference(\.novelUseSystemColor) var useSystemColor
        @Preference(\.novelFont) var novelFont

        @AppStorage(STTKeys.NovelFontColor) var fontColor: Color = .primary
        @AppStorage(STTKeys.NovelBGColor) var bgColor: Color = .primary

        let fontList: [NovelFont] = [
            .init(name: "Apple SD Gothic Neo", id: "AppleSDGothicNeo-Regular"),
            .init(name: "Arial", id: "ArialMT"),
            .init(name: "Arial Hebrew", id: "ArialHebrew"),
            .init(name: "Avenir", id: "Avenir-Regular"),
            .init(name: "Baskerville", id: "Baskerville"),
            .init(name: "Charter", id: "Charter"),
            .init(name: "Cochin", id: "Cochin"),
            .init(name: "Damascus", id: "Damascus"),
            .init(name: "Euphemia", id: "EuphemiaUCAS"),
            .init(name: "Geeza Pro", id: "GeezaPro"),
            .init(name: "Georgia", id: "Georgia"),
            .init(name: "Gill Sans", id: "GillSans"),
            .init(name: "Helvetica Neue", id: "HelveticaNeue"),
            .init(name: "Hoefler Text", id: "HoeflerText-Regular"),
            .init(name: "Kailasa", id: "Kailasa"),
            .init(name: "Kohinoor Bangla", id: "KohinoorBangla-Regular"),
            .init(name: "KohinoorDevanagari", id: "KohinoorDevanagari-Light"),
            .init(name: "Kohinor Telugu", id: "KohinoorTelugu-Regular"),
            .init(name: "Optima", id: "Optima-Regular"),
            .init(name: "Palatino", id: "Palatino-Roman"),
            .init(name: "PingFang HK", id: "PingFangHK-Regular"),
            .init(name: "PingFang SC", id: "PingFangSC-Regular"),
            .init(name: "PingFang TC", id: "PingFangTC-Regular"),
            .init(name: "Times New Roman", id: "TimesNewRomanPSMT"),
            .init(name: "Trebuchet MS", id: "TrebuchetMS"),
            .init(name: "Verdana", id: "Verdana"),
        ]

        var body: some View {
            NavigationView {
                Form {
                    Section {
                        Text("Lorem ipsum dolor sit amet")
                            .font(.custom(novelFont, size: CGFloat(fontSize)))
                            .foregroundColor(useSystemColor ? .primary : fontColor)
                            .listRowBackground(useSystemColor ? Color(uiColor: .systemBackground) : bgColor)
                    } header: {
                        Text("Preview")
                    }
                    Section {
                        NavigationLink {
                            Form {
                                Picker("Font", selection: $novelFont) {
                                    ForEach(fontList) { font in
                                        Text(font.name)
                                            .font(.custom(font.id, size: 20))
                                            .tag(font.id)
                                    }
                                }
                                .pickerStyle(.inline)
                            }

                        } label: {
                            STTLabelView(title: "Font", label: fontList.first(where: { $0.id == novelFont })?.name ?? "")
                        }

                        Stepper(value: $fontSize, in: 10 ... 35) {
                            HStack {
                                Text("Font Size")
                                Spacer()
                                Text("\(fontSize)")
                                    .foregroundColor(.gray)
                            }
                        }
                        Toggle("Use System Colors", isOn: $useSystemColor)

                        if !useSystemColor {
                            ColorPicker("Font Color", selection: $fontColor)
                            ColorPicker("Background Color", selection: $bgColor)
                        }
                    }

                    Section {
                        Picker("Reading Mode", selection: $useVertical) {
                            Text("Vertical")
                                .tag(true)
                            Text("Paged")
                                .tag(false)
                        }
                        .listStyle(.grouped)

                        if !useVertical {
                            Toggle("Double Paged", isOn: $useDoublePaged)
                        }

                        Toggle("Lock Orientation", isOn: $orientationLock)
                    }
                }
                .closeButton()
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .animation(.default, value: fontSize)
                .animation(.default, value: useVertical)
                .animation(.default, value: orientationLock)
                .animation(.default, value: useDoublePaged)
                .animation(.default, value: useSystemColor)
                .animation(.default, value: fontColor)
                .animation(.default, value: bgColor)
            }
        }
    }

    struct NovelFont: Identifiable {
        var name: String
        var id: String
    }
}
