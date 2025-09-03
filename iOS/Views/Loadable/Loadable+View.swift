//
//  Loadable+View.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import SwiftUI

struct LoadableView<Value, Idle, Loading, Content>: View where Idle: View,
    Loading: View,
    Content: View
{
    @Binding var loadable: Loadable<Value>
    let content: (_ value: Value) -> Content
    let idle: () -> Idle
    let loading: () -> Loading
    let action: () async throws -> Value

    let runnerID: String?
    init(
        runnerID: String? = nil,
        loadable: Binding<Loadable<Value>>,
        _ action: @escaping () async throws -> Value,
        @ViewBuilder _ idle: @escaping () -> Idle,
        @ViewBuilder _ loading: @escaping () -> Loading,
        @ViewBuilder _ content: @escaping (_ value: Value) -> Content
    ) {
        _loadable = loadable
        self.content = content
        self.loading = loading
        self.idle = idle
        self.action = action
        self.runnerID = runnerID
    }

    var body: some View {
        switch loadable {
        case .idle:
            idle()
            Rectangle()
                .hidden()
                .onAppear  {
                    Task {
                        await load()
                    }
                }
                .transition(.opacity)

        case .loading:
            loading()
                .transition(.opacity)

        case let .loaded(value):
            content(value)
                .transition(.opacity)

        case let .failed(error):
            ErrorView(error: error, runnerID: runnerID) {
                await animate {
                    loadable = .idle
                }
            }
            .transition(.opacity)
        }

    }
}

extension LoadableView {
    private func load(force: Bool = false) async {
        do {
            await animate {
                loadable = .loading
            }

            let data = try await action()

            await animate {
                loadable = .loaded(data)
            }

        } catch {
            Logger.shared.error(error)
            await animate {
                loadable = .failed(error)
            }
        }
    }
}

extension LoadableView where Idle == DefaultLoadingView, Loading == DefaultLoadingView {
    init(
        _ runnerID: String? = nil,
        _ action: @escaping () async throws -> Value,
        _ loadable: Binding<Loadable<Value>>,
        @ViewBuilder _ content: @escaping (_ value: Value) -> Content
    ) {
        self.init(runnerID: runnerID,
                  loadable: loadable,
                  action,
                  { DefaultLoadingView() },
                  { DefaultLoadingView() },
                  content)
    }
}

extension LoadableView where Idle == Loading {
    init(
        _ runnerID: String? = nil,
        _ action: @escaping () async throws -> Value,
        _ loadable: Binding<Loadable<Value>>,
        @ViewBuilder placeholder: @escaping () -> Idle,
        @ViewBuilder content: @escaping (_ value: Value) -> Content
    ) {
        self.init(runnerID: runnerID,
                  loadable: loadable,
                  action,
                  { placeholder() },
                  { placeholder() },
                  content)
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

struct OldLoadableView<Value, Idle, Loading, Failure, Content>: View where Idle: View,
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
                    .task {
                        if loaded {
                            loaded = false
                            await load()
                        }
                    }

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
            await MainActor.run {
                loadable = .failed(error)
            }
        }
    }
}

extension OldLoadableView where Idle == DefaultLoadingView, Loading == DefaultLoadingView, Failure == ErrorView {
    init(
        _ action: @escaping () async throws -> Void,
        _ loadable: Binding<Loadable<Value>>,
        @ViewBuilder _ content: @escaping (_ value: Value) -> Content
    ) {
        self.init(loadable: loadable,
                  action,
                  { DefaultLoadingView() },
                  { DefaultLoadingView() },
                  { ErrorView(error: $0, action: {
                      do {
                          try await action()
                      } catch {
                          await MainActor.run {
                              loadable.wrappedValue = .failed(error)
                          }
                      }
                  }) }, content)
    }
}

extension OldLoadableView where Failure == ErrorView, Idle == Loading {
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
