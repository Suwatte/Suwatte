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

        var lists: [DSKCommon.Option] {
            config?.lists ?? []
        }

        var showButton: Bool {
            !configSort.options.isEmpty || !lists.isEmpty
        }
        
        var fullSearch: Bool {
            request.tag == nil && (config == nil ? false : config?.searchable ?? true)
        }
    }
}

extension DirectoryView.ViewModel {
    private func getConfig() async throws {
        guard config == nil else {
            return
        }
        let config = try await runner.getDirectoryConfig(key: request.configID)
        await MainActor.run {
            withAnimation {
                self.config = config
            }
        }
    }

    func reset() {
        let prevSort = request.sort
        let key = request.configID
        request = .init(page: 1, configID: key)
        request.query = nil
        request.sort = prevSort
    }
}

extension DirectoryView.ViewModel {
    func sendRequest() async throws -> [DSKCommon.Highlight] {
        if config == nil {
            do {
                try await getConfig()
            } catch {
                Logger.shared.error(error)
            }
        }
        if config != nil && request.sort == nil {
            await MainActor.run {
                request.sort = configSort.default
                if request.sort == nil, let firstSortOption = configSort.options.first {
                    request.sort = .init(id: firstSortOption.id, ascending: nil)
                }
            }
        }

        if config != nil && request.sort == nil && request.listId == nil, let listID = config?.lists?.first?.id {
            await MainActor.run {
                request.listId = listID
            }
        }

        await MainActor.run {
            request.context = context
        }

        let data: DSKCommon.PagedResult = try await runner.getDirectory(request: request)

        await MainActor.run {
            resultCount = data.totalResultCount ?? data.results.count
            if data.isLastPage {
                pagination = .END
            }
        }

        return data.results
    }

    func reloadRequest() {
        result = .idle
        pagination = .IDLE
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
                    resultCount = data.totalResultCount ?? currentEntries.count
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

extension DirectoryView.ViewModel {
    func selectSortOption(_ option: DSKCommon.Option) {
        let q = request.query
        reset()
        if let currentSelection = request.sort, currentSelection.id == option.id, configSort.canChangeOrder ?? false {
            request.sort = .init(id: option.id, ascending: !(currentSelection.ascending ?? false))
        } else {
            request.sort = .init(id: option.id, ascending: false)
        }
        request.page = 1
        request.query = q
        reloadRequest()
    }

    func selectList(_ option: DSKCommon.Option) {
        reset()
        request.page = 1
        request.listId = option.id
        reloadRequest()
    }
}
