import SwiftUI

/// Écran des paramètres : compte Spotify, test de connexion, limitations iOS et à propos
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showLimitationsSheet = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.07)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Avertissement si Client ID non configuré
                        if !SpotifyConfig.isConfigured {
                            configWarningBanner
                        }
                        
                        // 1. Compte Spotify
                        spotifyAccountSection
                        
                        // 2. Limitations iOS & Fonctionnement
                        iosLimitationsSection
                        
                        // 3. À propos & Installation Sideloadly
                        aboutSection
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Paramètres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showLimitationsSheet) {
                IOSLimitationsView()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Sections
    
    private var configWarningBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 20))
                Text("Client ID Spotify manquant")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text("Veuillez renseigner votre Client ID dans le fichier SpotifyConfig.swift pour pouvoir vous connecter à votre compte.")
                .font(.subheadline)
                .foregroundColor(Color(white: 0.8))
        }
        .padding(16)
        .background(Color.yellow.opacity(0.15))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
        )
    }
    
    private var spotifyAccountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMPTE SPOTIFY")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .padding(.horizontal, 4)
            
            VStack(spacing: 14) {
                if viewModel.isConnected {
                    HStack(spacing: 14) {
                        // Avatar
                        if let avatarUrlString = viewModel.userProfile?.avatarUrl,
                           let url = URL(string: avatarUrlString) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.userProfile?.displayName ?? "Utilisateur Spotify")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 6) {
                                Text(viewModel.userProfile?.isPremium == true ? "Spotify Premium 🌟" : "Spotify Gratuit")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(red: 0.114, green: 0.725, blue: 0.329).opacity(0.2))
                                    .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                                    .cornerRadius(6)
                                
                                if let email = viewModel.userProfile?.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    
                    Divider().background(Color(white: 0.2))
                    
                    // Bouton de Test de connexion
                    Button(action: {
                        viewModel.testConnection()
                    }) {
                        HStack {
                            Image(systemName: "network")
                                .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                            Text("Tester la connexion Spotify")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Spacer()
                            if viewModel.isTestingConnection {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 13))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    
                    if let testMsg = viewModel.connectionTestMessage {
                        Text(testMsg)
                            .font(.caption)
                            .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                            .padding(.top, 2)
                    }
                    
                    Divider().background(Color(white: 0.2))
                    
                    // Bouton de Déconnexion
                    Button(action: {
                        viewModel.logout()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Se déconnecter de Spotify")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Non connecté
                    VStack(spacing: 16) {
                        Image(systemName: "music.note")
                            .font(.system(size: 36))
                            .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                        
                        Text("Connectez votre compte Spotify pour rechercher et jouer vos titres préférés.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        
                        Button(action: {
                            viewModel.login()
                        }) {
                            HStack(spacing: 10) {
                                if viewModel.isAuthenticating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                } else {
                                    Image(systemName: "link")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Se connecter avec Spotify")
                                        .font(.system(size: 15, weight: .bold))
                                }
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color(red: 0.114, green: 0.725, blue: 0.329))
                            .cornerRadius(23)
                        }
                        .disabled(viewModel.isAuthenticating)
                    }
                    .padding(.vertical, 8)
                }
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
            .padding(16)
            .background(Color(white: 0.12))
            .cornerRadius(16)
        }
    }
    
    private var iosLimitationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMPRENDRE LE FONCTIONNEMENT")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .padding(.horizontal, 4)
            
            Button(action: {
                showLimitationsSheet = true
            }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Limitations iOS & Fonctionnement")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Pourquoi et comment l'alarme sonne sur iPhone")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                .padding(14)
                .background(Color(white: 0.12))
                .cornerRadius(14)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("À PROPOS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
                .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
                infoRow(title: "Application", value: "Spotify Alarm")
                Divider().background(Color(white: 0.2))
                infoRow(title: "Version", value: "1.0.0 (Build 1)")
                Divider().background(Color(white: 0.2))
                infoRow(title: "Installation", value: "Sideloadly / Xcode")
                Divider().background(Color(white: 0.2))
                infoRow(title: "Protocole Auth", value: "OAuth 2.0 PKCE (RFC 7636)")
                Divider().background(Color(white: 0.2))
                infoRow(title: "Licence", value: "Open Source / Gratuit")
            }
            .padding(16)
            .background(Color(white: 0.12))
            .cornerRadius(14)
        }
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}
