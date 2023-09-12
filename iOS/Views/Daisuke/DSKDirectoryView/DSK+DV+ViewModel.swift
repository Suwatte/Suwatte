//
//  DSK+DV+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import SwiftUI

extension DirectoryView {
    final class ViewModel: ObservableObject {
        var runner: AnyRunner

        // Core
        @Published var result = Loadable<[DSKCommon.Highlight]>.idle
        @Published var config: DSKCommon.DirectoryConfig?
        @Published var request: DSKCommon.DirectoryRequest
        @Published var pagination = PaginationStatus.IDLE
        @Published var resultCount: Int?
        @Published var query = ""

        // Sheets
        @Published var presentFilters = false
        @Published var presentHistory = false
        @Published var callFromHistory = false

        let context: DSKCommon.CodableDict?
        var configSort: DSKCommon.DirectoryConfig.Sort {
            config?.sort ?? .init(options: [], default: nil, canChangeOrder: false)
        }

        var filters: [DSKCommon.DirectoryFilter] {
            config?.filters ?? []
        }

        init(runner: AnyRunner, request: DSKCommon.DirectoryRequest) {
            self.runner = runner
            self.request = request
            context = request.context
        }
    }
}

extension DirectoryView.ViewModel {
    private func getConfig() async throws {
        guard config == nil else {
            return
        }
        let config = try await runner.getDirectoryConfig(key: request.configKey)
        await MainActor.run {
            withAnimation {
                self.config = config
            }
        }
    }

    func reset() {
        let key = request.configKey
        request = .init(page: 1, configKey: key)
        request.query = nil
        request.sort = configSort.default
    }
}

extension DirectoryView.ViewModel {
    func makeRequest() async {
        // Update State
        await MainActor.run {
            result = .loading
        }
        do {
            if config == nil {
                do {
                    try await getConfig()
                } catch {
                    Logger.shared.error(error)
                }
            }
            if config != nil && request.sort == nil {
                if request.sort == nil {
                    await MainActor.run {
                        request.sort = configSort.default
                    }
                }
            }

            
            await MainActor.run {
                request.context = context
            }
            
            let data: DSKCommon.PagedResult = try await runner.getDirectory(request: request)

            await MainActor.run {
                withAnimation {
                    self.result = .loaded(data.results)
                    self.resultCount = data.totalResultCount
                    if data.isLastPage {
                        self.pagination = .END
                    }
                }
            }

        } catch {
            await MainActor.run {
                withAnimation {
                    self.result = .failed(error)
                }
            }
            Logger.shared.error(error, runner.id)
        }
    }

    func paginate() async {
        switch pagination {
        case .IDLE, .ERROR:
            break
        default:
            return
        }

        await MainActor.run {
            request.page += 1
            pagination = .LOADING
        }

        do {
            let data: DSKCommon.PagedResult = try await runner.getDirectory(request: request)
            if data.results.isEmpty {
                await MainActor.run {
                    self.pagination = .END
                }
                return
            }

            await MainActor.run {
                var currentEntries = self.result.value ?? []
                currentEntries.append(contentsOf: data.results)
                withAnimation {
                    self.result = .loaded(currentEntries)
                    if data.isLastPage {
                        self.pagination = .END
                        return
                    }
                    self.pagination = .IDLE
                }
            }

        } catch {
            await MainActor.run {
                self.pagination = .ERROR(error: error)
                self.request.page -= 1
            }
        }
    }
}

enum PaginationStatus: Equatable {
    case LOADING, END, ERROR(error: Error), IDLE

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.LOADING, .LOADING): return true
        case (.END, .END): return true
        case (.IDLE, .IDLE): return true
        case let (.ERROR(error: lhsE), .ERROR(error: rhsE)):
            return lhsE.localizedDescription == rhsE.localizedDescription
        default: return false
        }
    }
}
