package com.airship.features.trustlist

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.airship.designsystem.AirShipColors
import com.airship.designsystem.AirShipDimens
import com.airship.designsystem.AppNavigationTab
import com.airship.designsystem.FloatingBottomBar

@Composable
fun TrustListScreen(
    viewModel: TrustListViewModel,
    activeTab: AppNavigationTab,
    onTabSelected: (AppNavigationTab) -> Unit,
    modifier: Modifier = Modifier
) {
    val uiState by viewModel.uiState.collectAsState()

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(AirShipColors.PrimaryDarkBackground)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(20.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                SearchAndAddBar(
                    searchQuery = uiState.searchQuery,
                    isExpanded = uiState.isAddDrawerExpanded,
                    onSearchQueryChanged = { viewModel.updateSearchQuery(it) },
                    onToggleDrawer = { viewModel.toggleAddDrawer() }
                )

                if (uiState.isAddDrawerExpanded) {
                    AddUserDrawer(
                        userIdInput = uiState.newUserIdInput,
                        userAliasInput = uiState.newUserAliasInput,
                        onUserIdChanged = { viewModel.updateNewUserId(it) },
                        onUserAliasChanged = { viewModel.updateNewUserAlias(it) },
                        onSubmit = { viewModel.submitNewUser() }
                    )
                }

                PeerList(
                    peers = uiState.filteredPeers,
                    onToggleTrust = { viewModel.toggleTrust(it) },
                    onRemovePeer = { viewModel.removePeer(it) }
                )
            }

            FloatingBottomBar(
                currentTab = activeTab,
                onTabSelected = onTabSelected,
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .padding(bottom = 16.dp)
            )
        }
    }
}

@Composable
private fun SearchAndAddBar(
    searchQuery: String,
    isExpanded: Boolean,
    onSearchQueryChanged: (String) -> Unit,
    onToggleDrawer: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        TextField(
            value = searchQuery,
            onValueChange = onSearchQueryChanged,
            placeholder = { Text("Search by USER_NAME_ID", color = AirShipColors.TextSecondary) },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = "Search", tint = AirShipColors.TextSecondary) },
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(12.dp)),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = AirShipColors.SecondaryCardBackground,
                unfocusedContainerColor = AirShipColors.SecondaryCardBackground,
                focusedTextColor = AirShipColors.TextPrimary,
                unfocusedTextColor = AirShipColors.TextPrimary
            )
        )

        IconButton(
            onClick = onToggleDrawer,
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(AirShipColors.AccentCyan)
        ) {
            Icon(
                imageVector = if (isExpanded) Icons.Default.Close else Icons.Default.Add,
                contentDescription = "Add User",
                tint = AirShipColors.PrimaryDarkBackground
            )
        }
    }
}

@Composable
private fun AddUserDrawer(
    userIdInput: String,
    userAliasInput: String,
    onUserIdChanged: (String) -> Unit,
    onUserAliasChanged: (String) -> Unit,
    onSubmit: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AirShipDimens.CardCornerRadius))
            .background(AirShipColors.SecondaryCardBackground)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        OutlinedTextField(
            value = userIdInput,
            onValueChange = onUserIdChanged,
            label = { Text("Remote USER_NAME_ID") },
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = userAliasInput,
            onValueChange = onUserAliasChanged,
            label = { Text("Display Alias (optional)") },
            modifier = Modifier.fillMaxWidth()
        )
        Button(
            onClick = onSubmit,
            modifier = Modifier.fillMaxWidth().height(44.dp),
            colors = ButtonDefaults.buttonColors(containerColor = AirShipColors.AccentCyan, contentColor = AirShipColors.PrimaryDarkBackground),
            shape = RoundedCornerShape(AirShipDimens.PillCornerRadius)
        ) {
            Text(text = "Add User", fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun PeerList(
    peers: List<com.airship.corebridge.PeerBridgeModel>,
    onToggleTrust: (com.airship.corebridge.PeerBridgeModel) -> Unit,
    onRemovePeer: (com.airship.corebridge.PeerBridgeModel) -> Unit
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxWidth()
            .height(320.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(peers, key = { it.identifier }) { peer ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(AirShipColors.SecondaryCardBackground)
                    .padding(14.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.AccountCircle,
                        contentDescription = "Avatar",
                        tint = AirShipColors.AccentCyan,
                        modifier = Modifier.size(36.dp)
                    )
                    Column {
                        Text(text = peer.displayAlias, color = AirShipColors.TextPrimary, fontWeight = FontWeight.Bold)
                        Text(text = peer.identifier, color = AirShipColors.TextSecondary, fontSize = 12.sp)
                    }
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    IconButton(onClick = { onToggleTrust(peer) }) {
                        Icon(
                            imageVector = if (peer.isTrusted) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                            contentDescription = "Trust Toggle",
                            tint = if (peer.isTrusted) AirShipColors.AccentHeart else AirShipColors.TextSecondary
                        )
                    }
                    IconButton(onClick = { onRemovePeer(peer) }) {
                        Icon(
                            imageVector = Icons.Default.Delete,
                            contentDescription = "Delete",
                            tint = Color.Red.copy(alpha = 0.8f)
                        )
                    }
                }
            }
        }
    }
}
