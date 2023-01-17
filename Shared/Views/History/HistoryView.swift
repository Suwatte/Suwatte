//
//  HistoryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-01.
//

import RealmSwift
import SwiftUI

extension STTKeys {
    static var HistoryType = "APP.history_type"
}

struct HistoryView: View {
    @ObservedResults(ChapterMarker.self) var markers
    @AppStorage(STTKeys.HistoryType) var historyType = STTContentType.external

    var body: some View {
        Gateway
            .animation(.default, value: historyType)
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker(selection: $historyType) {
                            ForEach(STTContentType.allCases) { value in
                                Text(value.label)
                                    .tag(value)
                            }
                        } label: {
                            Label("Content Type", systemImage: "book")
                        }
                        .pickerStyle(.menu)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
    }

    @ViewBuilder
    var Gateway: some View {
        switch historyType {
        case .external:
            ExternalView(unfilteredMarkers: $markers)
        case .local:
            LocalView(unfilteredMarkers: $markers)
        case .opds:
            OPDSView()
        }
    }
}

extension HistoryView {
    struct StyleModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.primary.opacity(0.05))
                .cornerRadius(10)
        }
    }

    struct ProgressIndicator: View {
        var progress: CGFloat = 0.0
        @AppStorage(STTKeys.AppAccentColor) var color: Color = .sttDefault
        var width: CGFloat = 5.5

        var body: some View {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: .init(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .background(Circle().stroke(color.opacity(0.2), style: .init(lineWidth: width, lineCap: .round)))
                .frame(width: 40, height: 40, alignment: .center)
        }
    }
}

enum STTContentType: Int, CaseIterable, Identifiable {
    case external, local, opds

    var id: Int {
        hashValue
    }

    var label: String {
        switch self {
        case .external:
            return "Content Source"
        case .local:
            return "Local"
        case .opds:
            return "OPDS Stream"
        }
    }
}
