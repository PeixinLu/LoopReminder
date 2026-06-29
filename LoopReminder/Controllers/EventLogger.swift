import Foundation
import AppKit

@MainActor
final class EventLogger {
    static let shared = EventLogger()
    
    private let fileURL: URL
    private let dateFormatter: DateFormatter
    private let hiddenLogMarkers = ["[材质排查]"]
    
    private init() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = supportDir.appendingPathComponent("LoopReminder", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        self.fileURL = appDir.appendingPathComponent("logs.txt")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        self.dateFormatter = formatter
        
        // 确保文件存在
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }
    }
    
    func log(_ message: String) {
        let prefix = dateFormatter.string(from: Date())
        let line = "[\(prefix)] \(message)\n"
        
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            if let data = line.data(using: .utf8) {
                handle.write(data)
            }
            try? handle.close()
        } else {
            try? line.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    
    func readAll() -> [String] {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }
        return content
            .split(separator: "\n")
            .map(String.init)
            .filter { line in
                !hiddenLogMarkers.contains { marker in
                    line.contains(marker)
                }
            }
    }
    
    func clear() {
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    func openInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }
}
