import SwiftUI

public enum ModeSwitchOption: String, CaseIterable, Identifiable {
    case send = "Send"
    case receive = "Receive"

    public var id: String { rawValue }
}

public struct SegmentedToggleView: View {
    @Binding public var selectedOption: ModeSwitchOption

    public init(selectedOption: Binding<ModeSwitchOption>) {
        self._selectedOption = selectedOption
    }

    public var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(ModeSwitchOption.allCases, content: optionButton)
            }
            .padding(4)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
    }

    private func optionButton(for option: ModeSwitchOption) -> some View {
        let isSelected = selectedOption == option
        return Button {
            withAnimation(.snappy) {
                selectedOption = option
            }
        } label: {
            Text(option.rawValue)
                .font(.headline)
                .foregroundStyle(isSelected ? AirShipTheme.primaryDarkBackground : AirShipTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? AirShipTheme.accentCyan : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
