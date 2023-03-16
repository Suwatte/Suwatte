//
//  ESV+ViewModel.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//
import Combine

extension ExploreView.SearchView {
    final class ViewModel: ObservableObject {
        @Published var request: DaisukeEngine.Structs.SearchRequest
        @Published var sorters = [DaisukeEngine.Structs.SortOption]()
        @Published var query = ""
        @Published var result = Loadable<[DaisukeEngine.Structs.Highlight]>.idle
        @Published var resultCount: Int?
        @Published var presentFilters = false
        @Published var callFromHistory = false

        var source: AnyContentSource

        private var cancellables = Set<AnyCancellable>()

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

        @Published var paginationStatus = PaginationStatus.IDLE

        init(request: DaisukeEngine.Structs.SearchRequest = .init(), source: AnyContentSource) {
            self.request = request
            self.source = source
            Task {
                guard let res = try? await source.getSearchSortOptions() else {
                    return
                }
                await MainActor.run(body: {
                    sorters = res
                    if !sorters.isEmpty, self.request.sort == nil {
                        self.request.sort = sorters.first?.id
                    }
                })
            }
        }

        func softReset() {
            request.page = 1
            request.query = nil
            request.sort = sorters.first?.id
        }

        func makeRequest() async {
            await MainActor.run(body: {
                result = .loading
            })
            do {
                let data = try await source.getSearchResults(request)

                await MainActor.run(body: {
                    self.result = .loaded(data.results)
                    self.resultCount = data.totalResultCount
                })

            } catch {
                await MainActor.run(body: {
                    self.result = .failed(error)
                })
            }
        }

        func paginate() async {
            switch paginationStatus {
            case .IDLE, .ERROR:
                break
            default: return
            }

            await MainActor.run(body: {
                request.page? += 1
                paginationStatus = .LOADING
            })

            do {
                let response = try await source.getSearchResults(request)
                if response.results.isEmpty {
                    await MainActor.run(body: {
                        self.paginationStatus = .END
                    })
                    return
                }

                await MainActor.run(body: {
                    var currentEntries = self.result.value ?? []
                    currentEntries.append(contentsOf: response.results)
                    self.result = .loaded(currentEntries)
                    if response.isLastPage {
                        self.paginationStatus = .END
                        return
                    }

                    self.paginationStatus = .IDLE
                })

            } catch {
                await MainActor.run(body: {
                    self.paginationStatus = .ERROR(error: error)
                    self.request.page? -= 1
                })
            }
        }
    }
}
