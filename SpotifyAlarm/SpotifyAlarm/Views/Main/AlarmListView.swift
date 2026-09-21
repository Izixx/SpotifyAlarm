import SwiftUI

/// Écran principal listant les alarmes et permettant la gestion complète
public struct AlarmListView: View {
    @StateObject private var viewModel = AlarmListViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.07)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Barre d'état supérieure & actions rapides
                    topStatusBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    // Bouton de Test d'alarme
                    testAlarmBanner
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    
                    // Liste des alarmes
                    if viewModel.alarms.isEmpty {
                        emptyStateView
                    } else {
                        List {
                            ForEach(viewModel.alarms) { alarm in
                                AlarmRowView(
                                    alarm: alarm,
                                    onToggle: {
                                        viewModel.toggleAlarm(alarm)
                                    },
                                    onEdit: {
                                        viewModel.editingAlarm = alarm
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.deleteAlarm(id: alarm.id)
                                    } label: {
                                        Label("Supprimer", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .refreshable {
                            // Rechargement des alarmes
                            AlarmService.shared.loadAlarms()
                        }
                    }
                }
            }
            .navigationTitle("Spotify Alarm")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        viewModel.isNightstandPresented = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "bed.double.fill")
                            Text("Chevet")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(white: 0.15))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: {
                        viewModel.isSettingsPresented = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        viewModel.isCreatingAlarm = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 32, height: 32)
                            .background(Color(red: 0.114, green: 0.725, blue: 0.329))
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $viewModel.isCreatingAlarm) {
                AlarmEditView()
            }
            .sheet(item: $viewModel.editingAlarm) { alarm in
                AlarmEditView(alarm: alarm)
            }
            .sheet(isPresented: $viewModel.isSettingsPresented) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $viewModel.isNightstandPresented) {
                NightstandView()
            }
            .alert("Test d'alarme", isPresented: $viewModel.showTestAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.testAlertMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Composants UI
    
    private var topStatusBar: some View {
        HStack {
            // Statut Spotify
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isSpotifyConnected ? Color(red: 0.114, green: 0.725, blue: 0.329) : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.isSpotifyConnected ? "Spotify connecté" : "Spotify non connecté")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(viewModel.isSpotifyConnected ? .white : .orange)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(white: 0.12))
            .cornerRadius(12)
            
            Spacer()
            
            Text("\(viewModel.alarms.filter { $0.isEnabled }.count) active(s)")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    private var testAlarmBanner: some View {
        Button(action: {
            viewModel.runAlarmTest()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.114, green: 0.725, blue: 0.329).opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(Color(red: 0.114, green: 0.725, blue: 0.329))
                        .font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tester l'alarme immédiatement")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Vérifier son, notification et Spotify")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if viewModel.isTestingAlarm {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.114, green: 0.725, blue: 0.329)))
                } else {
                    Text("Lancer")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.114, green: 0.725, blue: 0.329))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
            }
            .padding(12)
            .background(Color(white: 0.12))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "alarm")
                .font(.system(size: 56))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Aucune alarme programmée")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Créez votre première alarme Spotify pour vous réveiller avec vos morceaux favoris.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                viewModel.isCreatingAlarm = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Nouvelle alarme")
                }
                .font(.system(size: 16, weight: .bold))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(red: 0.114, green: 0.725, blue: 0.329))
                .foregroundColor(.black)
                .cornerRadius(24)
            }
            .padding(.top, 10)
            
            Spacer()
        }
    }
}
