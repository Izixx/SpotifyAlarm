import SwiftUI

/// Vue détaillée de l'Hypnogramme et des statistiques d'une nuit de sommeil (façon Sleep Tracker / Sleep Cycle)
public struct HypnogramView: View {
    @Environment(\.dismiss) private var dismiss
    public let session: SleepSession
    
    public init(session: SleepSession) {
        self.session = session
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // MARK: - En-tête : Score & Résumé
                    headerCard
                    
                    // MARK: - Graphique Hypnogramme
                    hypnogramChartCard
                    
                    // MARK: - Répartition des 4 Phases de Sommeil
                    stagesBreakdownCard
                    
                    // MARK: - Analyse Acoustique & Ronflements
                    acousticAndSnoreCard
                    
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Détails de la nuit")
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
    
    // MARK: - En-tête : Score & Verdict
    
    private var headerCard: some View {
        HStack(spacing: 16) {
            // Jauge circulaire du score de sommeil
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(session.displaySleepScore) / 100.0)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(session.displaySleepScore)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("/ 100")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 80, height: 80)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.formattedNightSummary.capitalized)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(session.sleepScoreVerdict)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor)
                
                HStack(spacing: 12) {
                    Label(session.formattedDuration, systemImage: "clock.fill")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text("\(session.formattedStartTime) → \(session.formattedEndTime)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(18)
    }
    
    private var scoreColor: Color {
        switch session.displaySleepScore {
        case 85...100: return Color(red: 0.114, green: 0.725, blue: 0.329) // Vert Spotify
        case 75..<85:  return Color(red: 0.22, green: 0.75, blue: 0.95)   // Bleu cyan
        case 65..<75:  return Color.orange
        default:       return Color.red
        }
    }
    
    // MARK: - Carte de l'Hypnogramme
    
    private var hypnogramChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.purple)
                Text("Hypnogramme de la Nuit")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(session.stages.count) relevés")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Graphique personnalisé SwiftUI
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    // Axe vertical avec les libellés des 4 phases
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(SleepStage.allCases, id: \.self) { stage in
                            HStack(spacing: 4) {
                                Image(systemName: stage.systemIcon)
                                    .font(.system(size: 9))
                                Text(stage.shortName)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: stage.colorHex))
                            .frame(height: 36, alignment: .trailing)
                        }
                    }
                    .frame(width: 65)
                    
                    // Zone de dessin de la courbe
                    ZStack(alignment: .leading) {
                        // Lignes guides horizontales
                        VStack(spacing: 0) {
                            ForEach(0..<4) { _ in
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                    .frame(height: 36)
                            }
                        }
                        
                        // Tracé continu de l'hypnogramme
                        HypnogramCurveView(stages: session.stages)
                            .frame(height: 144)
                    }
                }
                .frame(height: 144)
                
                // Axe horizontal des heures
                HStack {
                    Spacer().frame(width: 73)
                    Text(session.formattedStartTime)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Milieu")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.5))
                    Spacer()
                    Text(session.formattedEndTime)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.top, 6)
            }
            .padding(.vertical, 8)
        }
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(18)
    }
    
    // MARK: - Répartition des 4 Phases
    
    private var stagesBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Phases de Sommeil")
                .font(.headline)
                .foregroundColor(.white)
            
            // Barre de ratio consolidée
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(Color(hex: SleepStage.deep.colorHex))
                        .frame(width: max(4, geo.size.width * (session.deepSleepPercentage / 100.0)))
                    Rectangle()
                        .fill(Color(hex: SleepStage.light.colorHex))
                        .frame(width: max(4, geo.size.width * (session.lightSleepPercentage / 100.0)))
                    Rectangle()
                        .fill(Color(hex: SleepStage.rem.colorHex))
                        .frame(width: max(4, geo.size.width * (session.remSleepPercentage / 100.0)))
                    Rectangle()
                        .fill(Color(hex: SleepStage.awake.colorHex))
                        .frame(width: max(4, geo.size.width * (session.awakePercentage / 100.0)))
                }
                .cornerRadius(6)
            }
            .frame(height: 12)
            
            // Détail phase par phase
            VStack(spacing: 10) {
                stageRow(
                    stage: .deep,
                    percentage: session.deepSleepPercentage,
                    duration: session.deepSleepDurationFormatted,
                    description: "Récupération physique & musculaire"
                )
                stageRow(
                    stage: .light,
                    percentage: session.lightSleepPercentage,
                    duration: session.lightSleepDurationFormatted,
                    description: "Repos du corps et transitions"
                )
                stageRow(
                    stage: .rem,
                    percentage: session.remSleepPercentage,
                    duration: session.remSleepDurationFormatted,
                    description: "Rêves & consolidation de la mémoire"
                )
                stageRow(
                    stage: .awake,
                    percentage: session.awakePercentage,
                    duration: session.awakeDurationFormatted,
                    description: "Micro-réveils nocturnes"
                )
            }
        }
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(18)
    }
    
    private func stageRow(stage: SleepStage, percentage: Double, duration: String, description: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: stage.colorHex))
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(stage.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                    Text(duration)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("(\(Int(percentage))%)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Analyse Acoustique & Ronflements
    
    private var acousticAndSnoreCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Environnement & Ronflements")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                // Ronflements
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.orange)
                        Text("Ronflements")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Text(session.formattedSnoreDuration)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(session.snoreEpisodesCount > 0 ? "\(session.snoreEpisodesCount) épisodes détectés" : "Sommeil silencieux")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(white: 0.16))
                .cornerRadius(12)
                
                // Niveau Sonore
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(.blue)
                        Text("Bruit ambiant")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Text("\(Int(session.averageSoundDB)) dB")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(session.soundEnvironmentDescription)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(white: 0.16))
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(18)
    }
}

// MARK: - Dessin de la Courbe Hypnogramme

struct HypnogramCurveView: View {
    let stages: [SleepStageEpoch]
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            if stages.count >= 2 {
                Path { path in
                    let stepX = w / CGFloat(stages.count - 1)
                    
                    for (index, epoch) in stages.enumerated() {
                        let x = CGFloat(index) * stepX
                        // chartLevel: 3 = Éveillé (haut, y=10), 0 = Profond (bas, y=h-10)
                        let normalizedLevel = CGFloat(3.0 - epoch.stage.chartLevel) / 3.0
                        let y = 10.0 + normalizedLevel * (h - 20.0)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            // Tracé en escalier progressif typique des hypnogrammes médicaux
                            let prevX = CGFloat(index - 1) * stepX
                            path.addLine(to: CGPoint(x: x, y: path.currentPoint?.y ?? y))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color.orange, Color.purple, Color.blue, Color(red: 0.1, green: 0.3, blue: 0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
            } else {
                Text("Données insuffisantes")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .position(x: w / 2, y: h / 2)
            }
        }
    }
}

// MARK: - Extension Couleur Hex

fileprivate extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
