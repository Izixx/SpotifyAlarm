import SwiftUI
import UniformTypeIdentifiers

/// Vue permettant d'importer et sélectionner un fichier MP3 / audio pour une alarme
public struct CustomAudioPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    public let currentFileName: String?
    public let onSelect: (CustomAudioFile?) -> Void
    
    @ObservedObject private var audioService = CustomAudioService.shared
    @ObservedObject private var playerService = AudioPlayerService.shared
    
    @State private var isFileImporterPresented: Bool = false
    @State private var currentlyPlayingURL: URL? = nil
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false
    
    public init(currentFileName: String? = nil, onSelect: @escaping (CustomAudioFile?) -> Void) {
        self.currentFileName = currentFileName
        self.onSelect = onSelect
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Bouton d'importation principal
                    importButton
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    
                    if audioService.audioFiles.isEmpty {
                        emptyStateView
                    } else {
                        filesListView
                    }
                }
            }
            .navigationTitle("Fichiers MP3 & Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        playerService.stopPreview()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.audio, .mp3],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert("Erreur d'importation", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Impossible d'importer ce fichier audio.")
            }
            .onDisappear {
                playerService.stopPreview()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Bouton d'Importation
    
    private var importButton: some View {
        Button(action: {
            isFileImporterPresented = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 18, weight: .bold))
                Text("Importer un fichier MP3 / Audio...")
                    .font(.headline)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(red: 0.114, green: 0.725, blue: 0.329))
            .cornerRadius(14)
        }
    }
    
    // MARK: - État Vide
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.4))
            
            Text("Aucun fichier audio importé")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Appuyez sur le bouton vert ci-dessus pour importer vos fichiers MP3, M4A ou WAV depuis l'application Fichiers ou iCloud Drive.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
    
    // MARK: - Liste des Fichiers
    
    private var filesListView: some View {
        List {
            Section {
                ForEach(audioService.audioFiles) { file in
                    fileRow(file: file)
                        .listRowBackground(Color(white: 0.12))
                        .listRowSeparatorTint(Color(white: 0.2))
                }
                .onDelete(perform: deleteFiles)
            } header: {
                Text("MES MORCEAUX IMPORTÉS (\(audioService.audioFiles.count))")
                    .font(.caption)
                    .foregroundColor(.gray)
            } footer: {
                Text("Glissez vers la gauche pour supprimer un fichier audio de l'application.")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Ligne de Fichier
    
    private func fileRow(file: CustomAudioFile) -> some View {
        let isSelected = currentFileName == file.fileName
        let isPlayingThis = playerService.isPreviewing && currentlyPlayingURL == file.fileURL
        
        return HStack(spacing: 12) {
            // Bouton Lecture / Pré-écoute
            Button(action: {
                if isPlayingThis {
                    playerService.stopPreview()
                    currentlyPlayingURL = nil
                } else {
                    currentlyPlayingURL = file.fileURL
                    playerService.playPreview(fileURL: file.fileURL)
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isPlayingThis ? Color(red: 0.114, green: 0.725, blue: 0.329) : Color(white: 0.25))
                        .frame(width: 40, height: 40)
                    Image(systemName: isPlayingThis ? "stop.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isPlayingThis ? .black : .white)
                }
            }
            .buttonStyle(.plain)
            
            // Titre et taille
            VStack(alignment: .leading, spacing: 3) {
                Text(file.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(file.formattedSize)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(file.fileURL.pathExtension.uppercased())
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(white: 0.2))
                        .cornerRadius(4)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Bouton Sélectionner
            Button(action: {
                playerService.stopPreview()
                onSelect(file)
                dismiss()
            }) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                } else {
                    Text("Choisir")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.114, green: 0.725, blue: 0.329).opacity(0.15))
                        .cornerRadius(12)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Actions
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let selectedURL = urls.first else { return }
            do {
                let imported = try audioService.importAudio(from: selectedURL)
                // Sélectionne automatiquement le fichier qui vient d'être importé
                onSelect(imported)
                dismiss()
            } catch {
                errorMessage = "Erreur lors de l'enregistrement : \(error.localizedDescription)"
                showErrorAlert = true
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = audioService.audioFiles[index]
            if currentlyPlayingURL == file.fileURL {
                playerService.stopPreview()
                currentlyPlayingURL = nil
            }
            audioService.deleteAudioFile(fileName: file.fileName)
        }
    }
}
