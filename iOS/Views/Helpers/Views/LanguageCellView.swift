//
//  LanguageCellView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-12-07.
//

import FlagKit
import SwiftUI

struct LanguageCellView: View {
    var language: String
    var body: some View {
        HStack {
            if let regionCode = Locale(identifier: language).regionCode, let flag = Flag(countryCode: regionCode) {
                Image(uiImage: flag.image(style: .roundedRect))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 21, height: 15)
            }
            Text(Locale.current.localizedString(forIdentifier: language) ?? language)
        }
    }
}
