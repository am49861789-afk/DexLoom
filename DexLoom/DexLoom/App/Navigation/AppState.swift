import SwiftUI

enum AppTab: String, CaseIterable {
    case home = "Home"
    case runtime = "Runtime"
    case inspector = "Inspector"
    case logs = "Logs"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .runtime: return "play.rectangle.fill"
        case .inspector: return "magnifyingglass"
        case .logs: return "doc.text.fill"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var bridge = RuntimeBridge()
}
