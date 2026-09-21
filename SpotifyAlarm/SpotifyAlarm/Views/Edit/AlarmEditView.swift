import SwiftUI

/// Écran de création ou modification d'une alarme
public struct AlarmEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AlarmEditViewModel
    
    public init(alarm: Alarm? = nil) {
        _viewModel = StateObject(wrappedValue: AlarmEditViewModel(alarm: alarm))
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.07)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Sélecteur d'Heure
                        VStack(spacing: 8) {
                            DatePicker(
                                "",
                                selection: $viewModel.time,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .frame(maxHeight: 180)
                        }
                        .padding(.vertical, 8)
                        .background(Color(white: 0.12))
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        
                        // 2. Titre de l'Alarme
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TITRE")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 4)
                            
                            TextField("Nom de l'alarme (ex: Réveil, Sport...)", text: $viewModel.title)
                                .padding(14)
                                .background(Color(white: 0.12))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        
                        // 3. Jours de Répétition
                        VStack(alignment: .leading, spacing: 10) {
                            Text("RÉPÉTITION")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 4)
                            
                            DaySelectorView(selectedDays: $viewModel.repeatDays)
                        }
                        .padding(.horizontal, 16)
                        
                        // 4. Choix de la Source Audio
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SOURCE AUDIO DU RÉVEIL")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 4)
                            
                            musicSelectionCard
                        }
                        .padding(.horizontal, 16)
                        
                        // 5. Vibrations au rythme de la musique
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $viewModel.vibrateOnBeat) {
                                HStack(spacing: 10) {
                                    Image(systemName: "waveform.path")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Vibrer sur le rythme")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        Text("Analyse les basses et le tempo pour caler les vibrations sur le rythme de la musique.")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .tint(Color(red: 0.114, green: 0.725, blue: 0.329))
                            .padding(14)
                            .background(Color(white: 0.12))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        
                        // 6. Réglage du Volume
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("VOLUME DE L'ALARME")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                Text("\(Int(viewModel.volume * 100)) %")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                            }
                            .padding(.horizontal, 4)
                            
                            HStack(spacing: 14) {
                                Image(systemName: "speaker.fill")
                                    .foregroundColor(.gray)
                                
                                Slider(value: $viewModel.volume, in: 0.05...1.0, step: 0.05)
                                    .accentColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                                
                                Image(systemName: "speaker.wave.3.fill")
                                    .foregroundColor(.gray)
                            }
                            .padding(14)
                            .background(Color(white: 0.12))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle(viewModel.isNew ? "Nouvelle alarme" : "Modifier l'alarme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        viewModel.save()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                }
            }
            .sheet(isPresented: $viewModel.isSpotifyPickerPresented) {
                SpotifyPickerView(currentSelection: viewModel.spotifyItem) { selectedItem in
                    viewModel.selectSpotifyItem(selectedItem)
                }
            }
            .sheet(isPresented: $viewModel.isCustomAudioPickerPresented) {
                CustomAudioPickerView(currentFileName: viewModel.customAudioFileName) { selectedFile in
                    viewModel.selectCustomAudio(selectedFile)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Carte de sélection musicale
    
    private var musicSelectionCard: some View {
        VStack(spacing: 10) {
            // Option 1 : Spotify
            Button(action: {
                viewModel.isSpotifyPickerPresented = true
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(viewModel.spotifyItem != nil ? Color(red: 0.114, green: 0.725, blue: 0.329) : Color(white: 0.2))
                            .frame(width: 42, height: 42)
                        Image(systemName: "music.note")
                            .foregroundColor(viewModel.spotifyItem != nil ? .black : .white)
                            .font(.system(size: 16, weight: .bold))
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Musique Spotify")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if let item = viewModel.spotifyItem {
                            Text("\(item.name) • \(item.artistName)")
                                .font(.caption)
                                .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                                .lineLimit(1)
                        } else {
                            Text("Rechercher un morceau, album ou playlist")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    if viewModel.spotifyItem != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
                .padding(12)
                .background(Color(white: 0.12))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            // Option 2 : Fichier MP3 / Audio
            Button(action: {
                viewModel.isCustomAudioPickerPresented = true
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(viewModel.customAudioFileName != nil ? Color.blue : Color(white: 0.2))
                            .frame(width: 42, height: 42)
                        Image(systemName: "arrow.down.doc.fill")
                            .foregroundColor(viewModel.customAudioFileName != nil ? .white : .white)
                            .font(.system(size: 16, weight: .bold))
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Fichier MP3 / Audio local")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if let title = viewModel.customAudioTitle, !title.isEmpty {
                            Text(title)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                        } else {
                            Text("Importer un fichier depuis l'app Fichiers ou iCloud")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    if viewModel.customAudioFileName != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
                .padding(12)
                .background(Color(white: 0.12))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            // Option 3 : Sonnerie standard (Carillon)
            Button(action: {
                viewModel.selectDefaultSound()
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(viewModel.spotifyItem == nil && viewModel.customAudioFileName == nil ? Color.orange : Color(white: 0.2))
                            .frame(width: 42, height: 42)
                        Image(systemName: "bell.fill")
                            .foregroundColor(viewModel.spotifyItem == nil && viewModel.customAudioFileName == nil ? .black : .white)
                            .font(.system(size: 16))
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sonnerie standard")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Carillon mélodique d'alarme intégré")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if viewModel.spotifyItem == nil && viewModel.customAudioFileName == nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.orange)
                    }
                }
                .padding(12)
                .background(Color(white: 0.12))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .background(Color(white: 0.12))
        .cornerRadius(12)
    }
    
    private func placeholderMusicArt(icon: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.2))
            Image(systemName: icon)
                .foregroundColor(.gray)
                .font(.system(size: 24))
        }
        .frame(width: 56, height: 56)
    }
}
