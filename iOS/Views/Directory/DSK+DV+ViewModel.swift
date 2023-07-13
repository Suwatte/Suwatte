//
//  DV+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import Foundation

extension DirectoryView {
    final class ViewModel: ObservableObject {
        var runner: JSCRunner

        // Core
        @Published var result = Loadable<[T]>.idle
        @Published var config: DSKCommon.DirectoryConfig?
        @Published var request: DSKCommon.DirectoryRequest
        @Published var pagination = PaginationStatus.IDLE
        @Published var resultCount: Int?
        @Published var query = ""

        // Sheets
        @Published var presentFilters = false
        @Published var presentHistory = false
        @Published var callFromHistory = false

        var sortOptions: [DSKCommon.Option] {
            config?.sortOptions ?? []
        }
        
        var filters: [DSKCommon.DirectoryFilter] {
            config?.filters ?? []
        }
        
        init(runner: JSCRunner, request: DSKCommon.DirectoryRequest) {
            self.runner = runner
            self.request = request
        }
    }
}

extension DirectoryView.ViewModel {
    func getConfig() {
        Task {
//            do {
//                let config = try await runner.getDirectoryConfig()
//                await MainActor.run {
//                    self.config = config
//                }
//            } catch {
//                Logger.shared.error(error, runner.id)
//            }
        }
    }

    func reset() {
//        request = .init(page: 1)
//        request.query = nil
//        request.sortKey = sortOptions.first?.key
    }
}

extension DirectoryView.ViewModel {
    func makeRequest() async {
        
        // Update State
//        await MainActor.run {
//            result = .loading
//            if request.sortKey == nil, let firstKey = sortOptions.first?.key {
//                request.sortKey = firstKey
//            }
//
//        }
//        do {
//            let data: DSKCommon.PagedResult<T> = try await runner.getDirectory(request: request)
//
//            await MainActor.run {
//                self.result = .loaded(data.results)
//                self.resultCount = data.totalResultCount
//            }
//
//        } catch {
//            await MainActor.run {
//                self.result = .failed(error)
//            }
//            Logger.shared.error(error, runner.id)
//        }
    }

    func paginate() async {
//        switch pagination {
//        case .IDLE, .ERROR:
//            break
//        default: return
//        }
//
//        await MainActor.run {
//            request.page += 1
//            pagination = .LOADING
//        }
//
//        do {
//            let data: DSKCommon.PagedResult<T> = try await runner.getDirectory(request: request)
//            if data.results.isEmpty {
//                await MainActor.run {
//                    self.pagination = .END
//                }
//                return
//            }
//
//            await MainActor.run {
//                var currentEntries = self.result.value ?? []
//                currentEntries.append(contentsOf: data.results)
//                self.result = .loaded(currentEntries)
//
//                if data.isLastPage {
//                    self.pagination = .END
//                    return
//                }
//
//                self.pagination = .IDLE
//            }
//
//        } catch {
//            await MainActor.run{
//                self.pagination = .ERROR(error: error)
//                self.request.page -= 1
//            }
//        }
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


