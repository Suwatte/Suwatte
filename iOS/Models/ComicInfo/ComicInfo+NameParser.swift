//
//  ComicInfo+NameParser.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-23.
//  Swift Implementation of the ComicTagger FileNameParser
//  Reference: https://github.com/comictagger/comictagger/blob/f43f51aa2f3f439aa69d42aa0a794d5cccd76877/comicapi/filenameparser.py
//  License: https://github.com/comictagger/comictagger/blob/develop/LICENSE

import Foundation

class ComicNameParser {
    struct Name: Hashable {
        let title: String
        let issue: Double?
        let volume: Double?
    }

    func getIssueNumber(filename: String) -> (String, Int, Int) {
        var filename = filename
        var found = false
        var issue = ""
        var start = 0
        var end = 0
        var volume: String?

        if filename.contains("--") {
            filename = filename.components(separatedBy: "--").first ?? ""
        } else if filename.contains("__"), !filename.contains("[__\\d+__]") {
            filename = filename.components(separatedBy: "__").first ?? ""
        }

        filename = filename.replacingOccurrences(of: "+", with: " ")
        filename = filename.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
        filename = filename.replacingOccurrences(of: "\\[.*?\\]", with: "", options: .regularExpression)
        filename = filename.replacingOccurrences(of: "  ", with: " ")
        filename = filename.replacingOccurrences(of: "of \\d+", with: "", options: .regularExpression)

        let volumeRegex = "(vol|volume)"
        if let range = filename.range(of: volumeRegex + "(\\d+)", options: .regularExpression, range: nil, locale: nil) {
            volume = String(filename[range])
        }

        var wordList = [Substring]()
        filename.enumerateSubstrings(in: filename.startIndex..., options: .byWords) { word, range, _, _ in
            if let word, !word.isEmpty {
                wordList.append(filename[range])
            }
        }
        if wordList.count > 1 {
            wordList.removeFirst()
        } else {
            if wordList[0].contains(where: { $0.isNumber }) {
                issue = wordList[0].trimmingCharacters(in: ["#"])
            }
            start = filename.startIndex.utf16Offset(in: filename)
            end = filename.endIndex.utf16Offset(in: filename)
            return (issue, start, end)
        }

        for w in wordList.reversed() {
            if w.range(of: "#-?(\\d*.\\d+|\\d+)(\\w*)", options: .regularExpression) != nil {
                found = true
                break
            }
        }

        if !found {
            if let w = wordList.last, w.range(of: "-?(\\d*.\\d+|\\d+)(\\w*)", options: .regularExpression) != nil {
                found = true
            }
        }

        if !found {
            for w in wordList.reversed() {
                if w.range(of: "#\\S+", options: .regularExpression) != nil {
                    found = true
                    break
                }
            }
        }

        if found {
            issue = String(wordList.last ?? "")
            start = filename.range(of: issue)?.lowerBound.utf16Offset(in: filename) ?? 0
            end = filename.range(of: issue)?.upperBound.utf16Offset(in: filename) ?? 0
            if issue.first == "#" {
                issue.removeFirst()
            }
        }

        return (issue, start, end)
    }

    func getSeriesName(filename: String, issueStart: Int) -> (String, String) {
        var filename = filename
        var volume = ""

        if issueStart != 0 {
            let index = filename.index(filename.startIndex, offsetBy: issueStart)
            filename = String(filename[..<index])
        } else {
            filename = filename.trimmingCharacters(in: ["#"])
        }

        if filename.contains("--") {
            filename = filename.components(separatedBy: "--").first ?? ""
        } else if filename.contains("__") {
            filename = filename.components(separatedBy: "__").first ?? ""
        }

        filename = filename.replacingOccurrences(of: "+", with: " ")
        filename = filename.replacingOccurrences(of: "  ", with: " ")
        filename = filename.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)

        let volumeRegex = "(vol|volume)"
        if let range = filename.range(of: "(.+)" + volumeRegex + "(\\d+)", options: .regularExpression, range: nil, locale: nil) {
            volume = String(filename[range])
            filename = filename.replacingOccurrences(of: volume, with: "")
        }

        if volume.isEmpty {
            if let range = filename.range(of: "\\(\\d{4}(-\\d{4}|)\\)", options: .regularExpression) {
                volume = String(filename[range])
            }
        }

        filename = filename.trimmingCharacters(in: .whitespacesAndNewlines)

        if issueStart == 0 {
            let oneShotWords = ["tpb", "os", "one-shot", "ogn", "gn"]
            if let lastWord = filename.split(separator: " ").last, oneShotWords.contains(lastWord.lowercased()) {
                filename = filename.replacingOccurrences(of: " \(lastWord)$", with: "")
            }
        }

        if !volume.isEmpty {
            filename = filename.replacingOccurrences(of: "\\s+v(|ol|olume)$", with: "", options: .regularExpression)
        }

        return (filename.trimmingCharacters(in: [" ", "-", "_", "."]), volume.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func getNameProperties(_ str: String) -> Name {
        let (issueStr, issueStart, _) = getIssueNumber(filename: str)
        let (series, volumeStr) = getSeriesName(filename: str, issueStart: issueStart)

        var formattedName = series
        var volume: Double?
        var issue: Double?

        if !volumeStr.isEmpty {
            volume = .init(volumeStr)
        }

        if !issueStr.isEmpty {
            issue = .init(issueStr)
        }
        return .init(title: series, issue: issue, volume: volume)
    }
}

extension ComicNameParser.Name {
    var formattedName: String {
        var out = title
        if let volume {
            out += " Vol. \(volume.clean)"
        }

        if let issue {
            out += " #\(issue.issue)"
        }

        return out
    }
}
