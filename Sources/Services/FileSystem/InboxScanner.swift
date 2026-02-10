import Foundation

/// Scans _Inbox/ folder for files to process
struct InboxScanner {
    let pkmRoot: String

    /// System files to ignore
    private static let ignoredFiles: Set<String> = [
        ".DS_Store", ".gitkeep", ".obsidian", "Thumbs.db",
    ]

    private static let ignoredPrefixes = [".", "_"]

    /// Scan inbox and return top-level items (both files and folders)
    func scan() -> [String] {
        let inboxPath = PKMPathManager(root: pkmRoot).inboxPath
        let fm = FileManager.default

        guard let entries = try? fm.contentsOfDirectory(atPath: inboxPath) else {
            return []
        }

        return entries.compactMap { name -> String? in
            guard !Self.ignoredFiles.contains(name) else { return nil }
            guard !Self.ignoredPrefixes.contains(where: { name.hasPrefix($0) }) else { return nil }

            let fullPath = (inboxPath as NSString).appendingPathComponent(name)
            guard fm.fileExists(atPath: fullPath) else { return nil }

            return fullPath
        }.sorted()
    }

    /// List all readable text files inside a directory (for content extraction)
    func filesInDirectory(at dirPath: String) -> [String] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: dirPath) else { return [] }

        return entries.compactMap { name -> String? in
            guard !Self.ignoredFiles.contains(name) else { return nil }
            guard !Self.ignoredPrefixes.contains(where: { name.hasPrefix($0) }) else { return nil }

            let fullPath = (dirPath as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue else { return nil }
            return fullPath
        }.sorted()
    }
}
