import SwiftUI

/// Vue explicative détaillée des règles iOS, des limitations techniques et des solutions implémentées
public struct IOSLimitationsView: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.07)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Bannière d'introduction
                        HStack(spacing: 14) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Fonctionnement & Règles iOS")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Comprendre comment fonctionne votre réveil sur iPhone.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(16)
                        .background(Color(white: 0.12))
                        .cornerRadius(16)
                        
                        // Section 1 : La règle Apple (Sandbox)
                        limitationSection(
                            icon: "lock.shield.fill",
                            iconColor: .orange,
                            title: "1. Restrictions d'arrière-plan iOS",
                            content: """
                            Sur iOS, le système d'exploitation suspend ou ferme les applications en arrière-plan pour préserver l'autonomie de la batterie.
                            
                            Apple interdit strictement à toute application tierce suspendue d'allumer arbitrairement l'audio ou de lancer une autre application en secret à une heure précise.
                            """
                        )
                        
                        // Section 2 : Notifications Time-Sensitive
                        limitationSection(
                            icon: "bell.badge.fill",
                            iconColor: Color(red: 0.114, green: 0.725, blue: 0.329),
                            title: "2. Déclenchement par Notification",
                            content: """
                            Pour garantir une sonnerie ponctuelle à la minute exacte :
                            
                            • Spotify Alarm utilise le framework officiel UNUserNotificationCenter avec le niveau 'Time-Sensitive'.
                            • La notification sonne avec une sonnerie puissante même en mode silencieux physique ou en mode Concentration Sommeil (si autorisée).
                            • Un bouton 'Lancer Spotify' apparaît sur votre écran verrouillé.
                            """
                        )
                        
                        // Section 3 : Spotify Web API & Deep Link
                        limitationSection(
                            icon: "music.note",
                            iconColor: .green,
                            title: "3. Lancement de la Musique Spotify",
                            content: """
                            Dès que vous touchez la notification ou le bouton 'Lancer Spotify' :
                            
                            1. Si vous possédez Spotify Premium et un appareil connecté actif, l'application commande immédiatement la lecture via l'API officielle Spotify.
                            2. L'application ouvre instantanément l'application native Spotify sur votre morceau ou playlist via un lien direct (Deep Link).
                            """
                        )
                        
                        // Section 4 : Secours Audio Local
                        limitationSection(
                            icon: "waveform.badge.magnifyingglass",
                            iconColor: .blue,
                            title: "4. Sécurité Anti-Panne de Réveil",
                            content: """
                            Que se passe-t-il sans connexion Internet ou sans Spotify installé ?
                            
                            Spotify Alarm intègre un carillon d'alarme de secours local (haute fidélité) configuré en catégorie Audio Playback. Vous ne manquerez jamais votre réveil même en mode avion.
                            """
                        )
                        
                        // Section 5 : Mode Chevet
                        limitationSection(
                            icon: "bed.double.fill",
                            iconColor: .purple,
                            title: "5. Astuce : Le Mode Chevet (100% Direct)",
                            content: """
                            Vous souhaitez que la musique démarre sans même toucher votre iPhone au réveil ?
                            
                            Laissez votre iPhone sur votre table de nuit branché au chargeur, avec l'écran Mode Chevet ouvert. L'application reste éveillée avec un écran noir basse consommation et lance directement la musique à l'heure programmée !
                            """
                        )
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Limitations iOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func limitationSection(icon: String, iconColor: Color, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 18))
                
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.8))
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.12))
        .cornerRadius(14)
    }
}
