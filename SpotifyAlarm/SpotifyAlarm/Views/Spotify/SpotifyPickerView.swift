import SwiftUI

/// Vue modale permettant de rechercher et sélectionner un morceau, album ou playlist Spotify
public struct SpotifyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SpotifyPickerViewModel()
    
    public let currentSelection: SpotifyTrackItem?
    public let onSelect: (SpotifyTrackItem) -> Void
    
    public init(currentSelection: SpotifyTrackItem?, onSelect: @escaping (SpotifyTrackItem) -> Void) {
        self.currentSelection = currentSelection
        self.onSelect = onSelect
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.07)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Barre de Recherche
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Rechercher un titre, artiste, playlist...", text: $viewModel.searchQuery)
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        
                        if !viewModel.searchQuery.isEmpty {
                            Button(action: { viewModel.searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(white: 0.15))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Sélecteur d'onglets (Recherche / Mes Playlists)
                    Picker("Onglet", selection: $viewModel.selectedTab) {
                        ForEach(PickerTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .onChange(of: viewModel.selectedTab) { newTab in
                        if newTab == .playlists && viewModel.userPlaylists.isEmpty {
                            viewModel.loadUserPlaylists()
                        }
                    }
                    
                    // Contenu selon l'onglet
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.114, green: 0.725, blue: 0.329)))
                            .scaleEffect(1.3)
                        Text("Chargement...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.top, 10)
                        Spacer()
                    } else if let error = viewModel.errorMessage {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 36))
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        Spacer()
                    } else {
                        listContent
                    }
                }
            }
            .navigationTitle("Choisir sur Spotify")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    @ViewBuilder
    private var listContent: some View {
        if viewModel.selectedTab == .search {
            if viewModel.searchResults.isEmpty {
                emptySearchState
            } else {
                List(viewModel.searchResults) { item in
                    SpotifyItemRow(
                        item: item,
                        isSelected: currentSelection?.id == item.id
                    ) {
                        onSelect(item)
                        dismiss()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Color(white: 0.18))
                }
                .listStyle(.plain)
            }
        } else {
            if viewModel.userPlaylists.isEmpty {
                emptyPlaylistsState
            } else {
                List(viewModel.userPlaylists) { item in
                    SpotifyItemRow(
                        item: item,
                        isSelected: currentSelection?.id == item.id
                    ) {
                        onSelect(item)
                        dismiss()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Color(white: 0.18))
                }
                .listStyle(.plain)
            }
        }
    }
    
    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.6))
            Text(viewModel.searchQuery.isEmpty ? "Tapez le nom d'un morceau pour rechercher" : "Aucun résultat trouvé")
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
        }
    }
    
    private var emptyPlaylistsState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.6))
            Text("Aucune playlist disponible")
                .font(.subheadline)
                .foregroundColor(.gray)
            Button("Actualiser") {
                viewModel.loadUserPlaylists()
            }
            .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
            Spacer()
        }
    }
}
