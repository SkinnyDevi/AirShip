package com.airship.features.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.airship.designsystem.AirShipColors
import com.airship.designsystem.AppNavigationTab
import com.airship.designsystem.BlimpLogo
import com.airship.designsystem.FloatingBottomBar
import com.airship.designsystem.SegmentedToggle

@Composable
fun HomeScreen(
    viewModel: HomeViewModel,
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
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Spacer(modifier = Modifier.weight(1f))

            BlimpLogo(size = 140.dp)

            Spacer(modifier = Modifier.weight(0.3f))

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = "Your Identity",
                    color = AirShipColors.TextSecondary,
                    fontSize = 14.sp
                )
                Text(
                    text = uiState.userNameId,
                    color = AirShipColors.TextPrimary,
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace
                )
            }

            Spacer(modifier = Modifier.weight(0.3f))

            SegmentedToggle(
                selectedOption = uiState.selectedMode,
                onOptionSelected = { viewModel.updateSelectedMode(it) },
                modifier = Modifier.padding(horizontal = 24.dp)
            )

            Spacer(modifier = Modifier.weight(1f))

            FloatingBottomBar(
                currentTab = activeTab,
                onTabSelected = onTabSelected,
                modifier = Modifier.padding(bottom = 16.dp)
            )
        }
    }
}
