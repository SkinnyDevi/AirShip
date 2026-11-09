import SwiftUI

public struct TrustListView: View {
    @ObservedObject public var viewModel: TrustListViewModel
    @Binding public var activeTab: NavigationTab

    public init(viewModel: TrustListViewModel, activeTab: Binding<NavigationTab>) {
        self.viewModel = viewModel
        self._activeTab = activeTab
    }

    public var body: some View {
        ZStack {
            AirShipTheme.primaryDarkBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                headerWithSearchAndAdd

                if viewModel.isAddDrawerExpanded {
                    addUserDrawer
                }

                peerListSection

                Spacer()

                FloatingBottomBar(activeTab: $activeTab)
                    .padding(.bottom, 16)
            }
            .padding(.top)
        }
        .task {
            await viewModel.loadPeers()
        }
    }

    private var headerWithSearchAndAdd: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AirShipTheme.textSecondary)
                TextField("Search by USER_NAME_ID", text: $viewModel.searchQuery)
                    .foregroundStyle(AirShipTheme.textPrimary)
            }
            .padding(10)
            .background(AirShipTheme.secondaryCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                withAnimation {
                    viewModel.isAddDrawerExpanded.toggle()
                }
            } label: {
                Image(systemName: viewModel.isAddDrawerExpanded ? "xmark" : "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AirShipTheme.primaryDarkBackground)
                    .frame(width: 44, height: 44)
                    .background(AirShipTheme.accentCyan)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
    }

    private var addUserDrawer: some View {
        VStack(spacing: 12) {
            TextField("Remote USER_NAME_ID", text: $viewModel.newUserIdInput)
                .textFieldStyle(.roundedBorder)

            TextField("Display Alias (optional)", text: $viewModel.newUserAliasInput)
                .textFieldStyle(.roundedBorder)

            Button {
                Task {
                    await viewModel.submitNewUser()
                }
            } label: {
                Text("Add User")
                    .font(.headline)
                    .foregroundStyle(AirShipTheme.primaryDarkBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AirShipTheme.accentCyan)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(AirShipTheme.secondaryCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AirShipTheme.cardCornerRadius))
        .padding(.horizontal)
    }

    private var peerListSection: some View {
        List {
            ForEach(viewModel.filteredPeers) { peer in
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(AirShipTheme.accentCyan)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(peer.displayAlias)
                            .font(.headline)
                            .foregroundStyle(AirShipTheme.textPrimary)
                        Text(peer.id)
                            .font(.caption)
                            .foregroundStyle(AirShipTheme.textSecondary)
                    }

                    Spacer()

                    Button {
                        Task {
                            await viewModel.toggleTrust(for: peer)
                        }
                    } label: {
                        Image(systemName: peer.isTrusted ? "heart.fill" : "heart")
                            .font(.system(size: 22))
                            .foregroundStyle(peer.isTrusted ? AirShipTheme.accentHeart : AirShipTheme.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await viewModel.removePeer(peer: peer)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(AirShipTheme.secondaryCardBackground)
            }
        }
        .listStyle(.plain)
        .padding(.horizontal)
    }
}
