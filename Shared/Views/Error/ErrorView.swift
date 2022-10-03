//
//  ErrorView.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import Kingfisher
import SwiftUI

struct ErrorView: View {
    var error: Error
    var action: () -> Void
    var sourceID: String?
    var body: some View {
        VStack {
            if case DaisukeEngine.Errors.NetworkErrorCloudflareProtected = error, let sourceID = sourceID {
                CloudFlareErrorView(sourceID: sourceID, action: action)
            } else {
                BaseErrorView
            }
        }
        .padding()
    }

    var BaseErrorView: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .imageScale(.large)
                .foregroundColor(.gray)
            VStack {
                Text("Oh Barnacles...")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(getMessage(for: error))
                    .font(.caption)
                    .fontWeight(.light)
                    .multilineTextAlignment(.center)
            }
            Button {
                action()
            }
                label: {
                Text("Retry")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: 100)
                    .background(Color.accentColor)
                    .cornerRadius(7)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            Logger.shared.error("[ErrorView] \(getMessage(for: error))")
        }
    }

    func getMessage(for error: Error) -> String {
        if case let DecodingError.valueNotFound(_, context) = error {
            return "JSON Decoding Error (Value not Found): \(context.debugDescription)"
        } else if case let DecodingError.typeMismatch(_, context) = error {
            return "JSON Decoding Error (Type Mismatch): \(context.debugDescription)"
        } else if case let DecodingError.dataCorrupted(context) = error {
            return "JSON Decoding Error (Corrupted Data): \(context.debugDescription)"
        } else if case let DecodingError.keyNotFound(_, context) = error {
            return "JSON Decoding Error (Key Not Found): \(context.debugDescription)"
        } else {
            return error.localizedDescription
        }
    }
}
