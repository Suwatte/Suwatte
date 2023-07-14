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
    var loadable: Loadable<Value>
    let content: (_ value: Value) -> Content
    let idle: () -> Idle
    let loading: () -> Loading
    let failure: (_ error: Error) -> Failure

    init(
        loadable: Loadable<Value>,
        @ViewBuilder _ idle: @escaping () -> Idle,
        @ViewBuilder _ loading: @escaping () -> Loading,
        @ViewBuilder _ failure: @escaping (_ error: Error) -> Failure,
        @ViewBuilder _ content: @escaping (_ value: Value) -> Content
    ) {
        self.loadable = loadable
        self.content = content
        self.loading = loading
        self.failure = failure
        self.idle = idle
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
    }
}

extension LoadableView where Idle == DefaultNotRequestedView, Loading == DefaultLoadingView, Failure == ErrorView {
    init(
        _ action: @escaping () -> Void,
        _ loadable: Loadable<Value>,
        @ViewBuilder _ content: @escaping (_ value: Value) -> Content
    ) {
        self.init(loadable: loadable, { DefaultNotRequestedView(action: action) }, { DefaultLoadingView() }, { ErrorView(error: $0, action: action) }, content)
    }
}

struct DefaultNotRequestedView: View {
    var action: () -> Void
    var body: some View {
        DefaultLoadingView()
            .task {
                action()
            }
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


