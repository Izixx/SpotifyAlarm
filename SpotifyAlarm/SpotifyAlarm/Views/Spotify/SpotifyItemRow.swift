import SwiftUI

/// Ligne d'affichage pour un élément musical Spotify (morceau, album ou playlist)
public struct SpotifyItemRow: View {
    public let item: SpotifyTrackItem
    public let isSelected: Bool
    public let onSelect: () -> Void
    
    public init(item: SpotifyTrackItem, isSelected: Bool = false, onSelect: @escaping () -> Void) {
        self.item = item
        self.isSelected = isSelected
        self.onSelect = onSelect
    }
    
    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Pochette / Artwork
                if let imageURLString = item.imageUrl, let url = URL(string: imageURLString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure(_), .empty:
                            placeholderArt
                        @unknown default:
                            placeholderArt
                        }
                    }
                    .frame(width: 52, height: 52)
                    .cornerRadius(8)
                } else {
                    placeholderArt
                }
                
                // Titre et artiste
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Image(systemName: item.type.iconName)
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                        
                        Text(item.artistName)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Indicateur de sélection
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                        .font(.system(size: 22))
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var placeholderArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.18))
            Image(systemName: item.type.iconName)
                .foregroundColor(.gray)
                .font(.system(size: 22))
        }
        .frame(width: 52, height: 52)
    }
}
