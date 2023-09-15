//
//  Realm+RunnerUpdate.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-15.
//

import Foundation

struct TaggedRunner: Identifiable, Hashable {
    let id: String
    let name: String
    let thumbnail: String
    let version: Double
    let listUrl: String

    static func from(_ object: StoredRunnerObject) -> Self {
        .init(id: object.id, name: object.name, thumbnail: object.thumbnail, version: object.version, listUrl: object.listURL)
    }
}

extension RealmActor {
    func getRunnerUpdates() async -> [TaggedRunner] {
        let runners: [StoredRunnerObject] = getSavedAndEnabledSources()
        let savedLists = getRunnerLists()
        struct RList {
            let list: RunnerList
            let url: String
        }
        let runnerLists = await withTaskGroup(of: RList?.self) { group in
            for list in savedLists {
                let urlString = list.url
                guard let url = URL(string: urlString) else { continue }
                group.addTask {
                    do {
                        let runnerList = try await DSK.shared.getRunnerList(at: url)
                        return .init(list: runnerList, url: urlString)
                    } catch {
                        Logger.shared.error(error, "CheckRunnerForUpdates")
                    }
                    return nil
                }
            }

            var out = [RList]()
            for await result in group {
                guard let result else { continue }
                out.append(result)
            }

            return out
        }

        var updates: [TaggedRunner] = []

        for runner in runners {
            let list = runnerLists.first(where: { $0.url == runner.listURL })
            guard let list, let _ = list.list.runners.first(where: { $0.id == runner.id && $0.version > runner.version }) else { continue }
            updates.append(.from(runner))
        }

        return updates.sorted(by: \.name, descending: false)
    }
}
