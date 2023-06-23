//
//  AnilistSignInView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-22.
//

import SwiftUI

extension AnilistView {
    struct SignInView: View {
        @ObservedObject var model = Anilist.shared
        @Environment(\.presentationMode) var presentationMode
        var body: some View {
            VStack(alignment: .center) {
                Image("anilist")
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width, height: 100, alignment: .center)
                    .clipShape(Circle())
                    .shadow(radius: 10)
                    .overlay(Circle().stroke(Color.anilistBlue, lineWidth: 1))
                    .shadow(color: .anilistBlue, radius: 10)
                    .padding(.vertical, 7)

                Text("Track, Share and Discover your favorite Manga & Anime with Anilist")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding()

                Button {
                    Anilist.shared.authenticate()
                } label: {
                    Text("Sign In")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(width: 150, height: 45, alignment: .center)
                        .background(Color.anilistBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                .onChange(of: model.notifier) { _ in
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .navigationTitle("Anilist")
        }
    }
}
