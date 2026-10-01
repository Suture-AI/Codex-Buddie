import AppKit
import CoreGraphics
import Foundation

// Read-only probe. Prints only Computer Use / ChatGPT window metadata, never pixels.
let seconds = CommandLine.arguments.dropFirst().first.flatMap(Double.init) ?? 0
let end = Date().addingTimeInterval(seconds)
var previous = ""
repeat {
    let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    let selected = windows.filter {
        let owner = $0[kCGWindowOwnerName as String] as? String ?? ""
        return owner.localizedCaseInsensitiveContains("computer use") || owner == "ChatGPT" || owner == "Codex"
    }.map { window in
        Dictionary(uniqueKeysWithValues: [kCGWindowNumber, kCGWindowOwnerName, kCGWindowName, kCGWindowOwnerPID, kCGWindowLayer, kCGWindowBounds, kCGWindowAlpha, kCGWindowIsOnscreen].compactMap { key -> (String, Any)? in
            guard let value = window[key as String] else { return nil }
            return (key as String, value)
        })
    }
    let data = try JSONSerialization.data(withJSONObject: selected, options: [.sortedKeys])
    let output = String(decoding: data, as: UTF8.self)
    if output != previous {
        print(output)
        fflush(stdout)
        previous = output
    }
    if seconds > 0 { Thread.sleep(forTimeInterval: 1.0 / 20.0) }
} while Date() < end
