import SwiftUI

public enum NavigationTab: String, CaseIterable, Identifiable {
    case transfer = "Transfer"
    case trustList = "Users"
    case settings = "Settings"

    public var id: String { rawValue }

    public var systemIconName: String {
        switch self {
        case .transfer:
            return "airplane.circle"
        case .trustList:
            return "person.2.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
}

public struct FloatingBottomBar: View {
    @Binding public var activeTab: NavigationTab

    public init(activeTab: Binding<NavigationTab>) {
        self._activeTab = activeTab
    }

    public var body: some View {
        HStack(spacing: 40) {
            ForEach(NavigationTab.allCases) { tab in
                let isSelected = activeTab == tab
                Button {
                    activeTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemIconName)
                            .font(.system(size: 22, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .foregroundStyle(isSelected ? AirShipTheme.accentCyan : AirShipTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(AirShipTheme.secondaryCardBackground.opacity(0.95))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.35), radius: 10, y: 5)
    }
}
