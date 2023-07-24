//
//  ErrorView.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import SwiftUI

struct ErrorView: View {
    var error: Error
    var runnerID: String?
    var action: () -> Void
    var body: some View {
        Group {
            VStack(alignment: .center) {
                if case DaisukeEngine.Errors.Cloudflare = error, let runnerID = runnerID {
                    CloudFlareErrorView(sourceID: runnerID, action: action)
                } else {
                    BaseErrorView
                }
            }
        }
        .frame(maxWidth: .infinity)
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
        } else if case let DSK.Errors.NetworkError(message, _) = error {
            return "Network Error: \(message)"
        } else if case let DSK.Errors.NamedError(name, message) = error {
            return "\(name): \(message)"
        } else {
            return error.localizedDescription
        }
    }
}
