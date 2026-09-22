import SwiftUI

/// Vue racine de l'application avec barre d'onglets native (Alarmes, Sommeil, Paramètres)
public struct MainTabView: View {
    @State private var selectedTab: Int = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            AlarmListView()
                .tabItem {
                    Label("Alarmes", systemImage: "alarm.fill")
                }
                .tag(0)
            
            SleepTrackerView()
                .tabItem {
                    Label("Sommeil", systemImage: "moon.stars.fill")
                }
                .tag(1)
            
            SettingsView(isSheet: false)
                .tabItem {
                    Label("Paramètres", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .accentColor(Color(red: 0.114, green: 0.725, blue: 0.329))
        .preferredColorScheme(.dark)
    }
}
