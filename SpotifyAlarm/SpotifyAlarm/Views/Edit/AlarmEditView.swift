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
                        
                        // 4. Choix de la Musique Spotify
                        VStack(alignment: .leading, spacing: 10) {
                            Text("MUSIQUE DU RÉVEIL")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 4)
                            
                            musicSelectionCard
                        }
                        .padding(.horizontal, 16)
                        
                        // 5. Réglage du Volume
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
                    viewModel.spotifyItem = selectedItem
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Carte de sélection musicale
    
    private var musicSelectionCard: some View {
        VStack(spacing: 0) {
            if let item = viewModel.spotifyItem {
                HStack(spacing: 14) {
                    if let imageURLString = item.imageUrl, let url = URL(string: imageURLString) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                placeholderMusicArt(icon: item.type.iconName)
                            }
                        }
                        .frame(width: 56, height: 56)
                        .cornerRadius(8)
                    } else {
                        placeholderMusicArt(icon: item.type.iconName)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(item.artistName)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: { viewModel.isSpotifyPickerPresented = true }) {
                        Text("Modifier")
                            .font(.subheadline)
                            .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                    }
                }
                .padding(14)
            } else {
                Button(action: {
                    viewModel.isSpotifyPickerPresented = true
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.114, green: 0.725, blue: 0.329))
                                .frame(width: 36, height: 36)
                            Image(systemName: "music.note")
                                .foregroundColor(.black)
                                .font(.system(size: 16, weight: .bold))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Choisir sur Spotify")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Aucune musique sélectionnée (Sonnerie carillon par défaut)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)
            }
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
