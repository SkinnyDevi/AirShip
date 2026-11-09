package com.airship.designsystem

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

object AirShipColors {
    val PrimaryDarkBackground = Color(0xFF14171E)
    val SecondaryCardBackground = Color(0xFF242933)
    val AccentCyan = Color(0xFF00D9F2)
    val AccentHeart = Color(0xFFFA426B)
    val TextPrimary = Color(0xFFFFFFFF)
    val TextSecondary = Color(0xFFB0B7C3)
}

object AirShipDimens {
    val PillCornerRadius = 28.dp
    val CardCornerRadius = 16.dp
}

private val DarkColorScheme = darkColorScheme(
    primary = AirShipColors.AccentCyan,
    background = AirShipColors.PrimaryDarkBackground,
    surface = AirShipColors.SecondaryCardBackground,
    onPrimary = AirShipColors.PrimaryDarkBackground,
    onBackground = AirShipColors.TextPrimary,
    onSurface = AirShipColors.TextPrimary
)

@Composable
fun AirShipTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        content = content
    )
}
