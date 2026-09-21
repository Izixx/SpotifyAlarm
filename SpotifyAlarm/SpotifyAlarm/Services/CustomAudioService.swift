import Foundation
import UniformTypeIdentifiers

/// Modèle représentant un fichier audio personnalisé importé par l'utilisateur
public struct CustomAudioFile: Identifiable, Equatable, Hashable {
    public var id: String { fileName }
    public let fileName: String
    public let title: String
    public let fileURL: URL
    public let sizeInBytes: Int64
    
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeInBytes)
    }
}

/// Service de gestion des fichiers audio personnalisés (MP3, M4A, WAV)
public final class CustomAudioService: ObservableObject {
    
    public static let shared = CustomAudioService()
    
    @Published public var audioFiles: [CustomAudioFile] = []
    
    private let fileManager = FileManager.default
    
    private var customAudioDirectoryURL: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDir = documents.appendingPathComponent("CustomAudio", isDirectory: true)
        if !fileManager.fileExists(atPath: audioDir.path) {
            try? fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
        }
        return audioDir
    }
    
    private init() {
        refreshFiles()
    }
    
    /// Rafraîchit la liste des fichiers audio disponibles dans le stockage local
    public func refreshFiles() {
        let dir = customAudioDirectoryURL
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            self.audioFiles = []
            return
        }
        
        var list: [CustomAudioFile] = []
        for url in fileURLs {
            let ext = url.pathExtension.lowercased()
            guard ["mp3", "m4a", "wav", "aac", "aiff"].contains(ext) else { continue }
            
            let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
            let size = Int64(resourceValues?.fileSize ?? 0)
            let fileName = url.lastPathComponent
            
            // Titre d'affichage convivial
            var title = url.deletingPathExtension().lastPathComponent
            if let underscoreIndex = title.firstIndex(of: "_"), title.distance(from: title.startIndex, to: underscoreIndex) == 36 {
                // Supprime le préfixe UUID pour afficher le vrai nom d'origine
                title = String(title[title.index(after: underscoreIndex)...])
            }
            
            list.append(CustomAudioFile(
                fileName: fileName,
                title: title,
                fileURL: url,
                sizeInBytes: size
            ))
        }
        
        self.audioFiles = list.sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })
    }
    
    /// Importe un fichier audio depuis une URL sécurisée (UIDocumentPicker / fileImporter)
    /// - Parameter sourceURL: URL du fichier sélectionné
    /// - Returns: Le fichier audio importé
    public func importAudio(from sourceURL: URL) throws -> CustomAudioFile {
        let isSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let originalName = sourceURL.lastPathComponent
        let sanitizedOriginal = originalName.replacingOccurrences(of: " ", with: "_")
        let uniqueName = "\(UUID().uuidString)_\(sanitizedOriginal)"
        let destinationURL = customAudioDirectoryURL.appendingPathComponent(uniqueName)
        
        // Copie du fichier dans le répertoire de l'application
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        refreshFiles()
        
        guard let imported = audioFiles.first(where: { $0.fileName == uniqueName }) else {
            throw NSError(domain: "CustomAudioService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Impossible de localiser le fichier importé."])
        }
        return imported
    }
    
    /// Supprime un fichier audio importé
    public func deleteAudioFile(fileName: String) {
        let fileURL = customAudioDirectoryURL.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
        refreshFiles()
    }
    
    /// Renvoie l'URL absolue locale d'un fichier audio par son nom
    public func fileURL(for fileName: String) -> URL? {
        let url = customAudioDirectoryURL.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }
}
