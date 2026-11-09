package com.airship.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

enum class AppNavigationTab(
    val title: String,
    val icon: ImageVector
) {
    Transfer("Transfer", Icons.Default.Home),
    TrustList("Users", Icons.Default.AccountCircle),
    Settings("Settings", Icons.Default.Settings)
}

@Composable
fun FloatingBottomBar(
    currentTab: AppNavigationTab,
    onTabSelected: (AppNavigationTab) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(AirShipDimens.PillCornerRadius))
            .background(AirShipColors.SecondaryCardBackground.copy(alpha = 0.95f))
            .padding(horizontal = 28.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(40.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AppNavigationTab.entries.forEach { tab ->
            val isSelected = currentTab == tab
            val tintColor = if (isSelected) AirShipColors.AccentCyan else AirShipColors.TextSecondary

            Column(
                modifier = Modifier.clickable { onTabSelected(tab) },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(
                    imageVector = tab.icon,
                    contentDescription = tab.title,
                    tint = tintColor
                )
                Text(
                    text = tab.title,
                    color = tintColor,
                    fontSize = 10.sp
                )
            }
        }
    }
}
