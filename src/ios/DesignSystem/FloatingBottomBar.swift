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
        GlassEffectContainer(spacing: 24) {
            HStack(spacing: 36) {
                ForEach(NavigationTab.allCases, content: tabButton)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
    }

    private func tabButton(for tab: NavigationTab) -> some View {
        let isSelected = activeTab == tab
        return Button {
            withAnimation(.bouncy) {
                activeTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemIconName)
                    .font(.system(size: 22, weight: .semibold))
                Text(tab.rawValue)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? AirShipTheme.accentCyan : AirShipTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
