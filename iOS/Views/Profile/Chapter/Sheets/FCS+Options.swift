//
//  FCS+Options.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-05.
//

import SwiftUI

struct FCS_Options: View {
    @EnvironmentObject var model: ProfileView.ViewModel
    @AppStorage(STTKeys.FilteredProviders) private var filteredProviders: [String] = []
    @AppStorage(STTKeys.FilteredLanguages) private var filteredLanguages: [String] = []

    var body: some View {
        SmartNavigationView {
            List {}
                .closeButton()
                .navigationBarTitle("Filter")
                .animation(.default, value: filteredProviders)
        }
    }

    var ProvidersSection: some View {
        Section {} header: {
            Text("Providers")
        }
    }
}

//
// extension FCS_Options {
//    var AllProviders: [DSKCommon.ChapterProvider] {
//        let providers = model
//            .threadSafeChapters?
//            .map { $0.providers ?? [] }
//            .flatMap { $0 } ?? []
//
//        return providers
//            .distinct()
//            .sorted(by: \.name, descending: false)
//    }
//
//    func toggleProvider(_ provider: DSKCommon.ChapterProvider) {
//        if filteredProviders.contains(provider.id) {
//            filteredProviders.removeAll(where: { $0 == provider.id })
//        } else {
//            filteredProviders.append(provider.id)
//        }
//    }
// }
//
// extension FCS_Options {
//    var AllLanugages: [String] {
//        (model
//            .threadSafeChapters?
//            .compactMap { $0.language } ?? [])
//            .distinct()
//    }
//
//    func toggleLangauge(_ lang: String) {
//        if filteredLanguages.contains(lang) {
//            filteredLanguages.removeAll(where: { $0 == lang })
//        } else {
//            filteredLanguages.append(lang)
//        }
//    }
//
//    var LanguagesSection: some View {
//        Section {
//            ForEach(AllLanugages) { lang in
//                Button { toggleLangauge(lang) } label: {
//                    HStack {
//                        LanguageCellView(language: lang)
//                        Spacer()
//                        Image(systemName: "eye.slash")
//                            .foregroundColor(.red)
//                            .opacity(filteredLanguages.contains(lang) ? 1 : 0)
//                    }
//                    .contentShape(Rectangle())
//                }
//                .buttonStyle(.plain)
//            }
//        } header: {
//            Text("Languages")
//        }
//    }
// }
