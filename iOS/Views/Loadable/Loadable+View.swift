//
//  Loadable+View.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import SwiftUI

struct LoadableView<Value, Idle, Loading, Failure, Content>: View where Idle: View,
    Loading: View,
    Failure: View,
    Content: View
{
    @Binding var loadable: Loadable<Value>
    let content: (_ value: Value) -> Content
    let idle: () -> Idle
    let loading: () -> Loading
    let failure: (_ error: Error) -> Failure
    let action: () async throws -> Void
    @State private var loaded = false

    init(
        loadable: Binding<Loadable<Value>>,
        _ action: @escaping () async throws -> Void,
        @ViewBuilder _ idle: @escaping () -> Idle,
        @ViewBuilder _ loading: @escaping () -> Loading,
        @ViewBuilder _ failure: @escaping (_ error: Error) -> Failure,
        @ViewBuilder _ content: @escaping (_ value: Value) -> Content
    ) {
        _loadable = loadable
        self.content = content
        self.loading = loading
        self.failure = failure
        self.idle = idle
        self.action = action
    }

    var body: some View {
        Group {
            switch loadable {
            case .idle:
                idle()
                    .transition(.opacity)
            case .loading:
                loading()
                    .transition(.opacity)

            case let .loaded(value):
                content(value)
                    .transition(.opacity)

            case let .failed(error):
                failure(error)
                    .transition(.opacity)
            }
        }
        .task {
            await load()
        }
    }

    func load() async {
        guard !loaded else { return }
        do {
            await MainActor.run {
                loadable = .loading
            }
            try await action()
            loaded = true
        } catch {
            Logger.shared.error(error)
            loadable = .failed(error)
        }
    }
}

extension LoadableView where Idle == DefaultNotRequestedView, Loading == DefaultLoadingView, Failure == ErrorView {
    init(
        _ action: @escaping () async throws -> Void,
        _ loadable: Binding<Loadable<Value>>,
        @ViewBuilder _ content: @escaping (_ value: Value) -> Content
    ) {
        self.init(loadable: loadable,
                  action,
                  { DefaultNotRequestedView() },
                  { DefaultLoadingView() },
                  { ErrorView(error: $0, action: {
                      do {
                          try await action()
                      } catch {
                          loadable.wrappedValue = .failed(error)
                      }
                  }) }, content)
    }
}

extension LoadableView where Failure == ErrorView, Idle == Loading {
    init(
        _ action: @escaping () async throws -> Void,
        _ loadable: Binding<Loadable<Value>>,
        @ViewBuilder placeholder: @escaping () -> Idle,
        @ViewBuilder content: @escaping (_ value: Value) -> Content
    ) {
        self.init(loadable: loadable,
                  action,
                  { placeholder() },
                  { placeholder() },
                  { ErrorView(error: $0, action: {
                      do {
                          try await action()
                      } catch {
                          loadable.wrappedValue = .failed(error)
                      }
                  }) }, content)
    }
}

struct DefaultNotRequestedView: View {
    var body: some View {
        DefaultLoadingView()
    }
}

struct DefaultLoadingView: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
    }
}
