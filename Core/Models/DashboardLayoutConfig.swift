import SwiftUI
import Combine

enum DashboardCardType: String, Codable, CaseIterable, Identifiable {
    case nutrition, steps, weight, training, recovery, energy, water, sleep, mood
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .nutrition: return "Ernährung"
        case .steps: return "Schritte"
        case .weight: return "Gewicht"
        case .training: return "Training"
        case .recovery: return "Recovery"
        case .energy: return "Tagesenergie"
        case .water: return "Wasser"
        case .sleep: return "Schlaf"
        case .mood: return "Stimmung"
        }
    }
    
    var icon: String {
        switch self {
        case .nutrition: return "flame.fill"
        case .steps: return "figure.walk"
        case .weight: return "scalemass"
        case .training: return "figure.run"
        case .recovery: return "heart.text.square.fill"
        case .energy: return "bolt.batteryblock.fill"
        case .water: return "drop.fill"
        case .sleep: return "moon.zzz.fill"
        case .mood: return "face.smiling.fill"
        }
    }
}

enum DashboardCardSize: String, Codable {
    case small  // Half width (2-column grid)
    case large  // Full width
}

struct DashboardCardConfig: Codable, Identifiable, Equatable {
    let type: DashboardCardType
    var size: DashboardCardSize
    var id: String { type.rawValue }
    
    static let defaultLayout: [DashboardCardConfig] = [
        DashboardCardConfig(type: .recovery, size: .small),
        DashboardCardConfig(type: .energy, size: .small),
        DashboardCardConfig(type: .nutrition, size: .large),
        DashboardCardConfig(type: .steps, size: .small),
        DashboardCardConfig(type: .weight, size: .small),
        DashboardCardConfig(type: .training, size: .small),
        DashboardCardConfig(type: .water, size: .small),
        DashboardCardConfig(type: .sleep, size: .large),
        DashboardCardConfig(type: .mood, size: .large),
    ]
}

class DashboardLayoutManager: ObservableObject {
    @Published var cards: [DashboardCardConfig] = [] {
        didSet { save() }
    }
    
    @Published var draggedItem: DashboardCardType? = nil
    @Published var hoveredArea: String? = nil
    
    private let storageKey = "dashboard_layout_config"
    private var observer: Any?
    
    init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            self?.load()
        }
        NSUbiquitousKeyValueStore.default.synchronize()
        load()
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func load() {
        var dataToDecode: Data? = nil
        
        if let data = NSUbiquitousKeyValueStore.default.data(forKey: storageKey) {
            dataToDecode = data
            UserDefaults.standard.set(data, forKey: storageKey)
        } else if let data = UserDefaults.standard.data(forKey: storageKey) {
            dataToDecode = data
            NSUbiquitousKeyValueStore.default.set(data, forKey: storageKey)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
        
        if let data = dataToDecode,
           let decoded = try? JSONDecoder().decode([DashboardCardConfig].self, from: data),
           !decoded.isEmpty {
            
            var loadedCards = decoded
            for defaultCard in DashboardCardConfig.defaultLayout {
                if !loadedCards.contains(where: { $0.type == defaultCard.type }) {
                    loadedCards.append(defaultCard)
                }
            }
            self.cards = loadedCards
        } else {
            self.cards = DashboardCardConfig.defaultLayout
        }
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(data, forKey: storageKey)
            NSUbiquitousKeyValueStore.default.set(data, forKey: storageKey)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
    
    func move(from source: IndexSet, to destination: Int) {
        cards.move(fromOffsets: source, toOffset: destination)
    }
    
    func moveCard(from sourceCard: DashboardCardType, to destinationCard: DashboardCardType) {
        guard sourceCard != destinationCard else { return }
        guard let sourceIndex = cards.firstIndex(where: { $0.type == sourceCard }),
              let destIndex = cards.firstIndex(where: { $0.type == destinationCard }) else { return }
        
        let card = cards.remove(at: sourceIndex)
        // If moving down, the destIndex shifted by 1.
        let insertIndex = sourceIndex < destIndex ? destIndex : destIndex
        cards.insert(card, at: insertIndex)
    }
    
    func toggleSize(for cardType: DashboardCardType) {
        if let index = cards.firstIndex(where: { $0.type == cardType }) {
            cards[index].size = cards[index].size == .large ? .small : .large
        }
    }
    
    func resetToDefault() {
        cards = DashboardCardConfig.defaultLayout
    }
}
