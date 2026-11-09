package com.airship.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

enum class TransferModeOption {
    Send,
    Receive
}

@Composable
fun SegmentedToggle(
    selectedOption: TransferModeOption,
    onOptionSelected: (TransferModeOption) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AirShipDimens.PillCornerRadius))
            .background(AirShipColors.SecondaryCardBackground)
            .padding(4.dp)
    ) {
        TransferModeOption.entries.forEach { option ->
            val isSelected = selectedOption == option
            val backgroundColor = if (isSelected) AirShipColors.AccentCyan else Color.Transparent
            val textColor = if (isSelected) AirShipColors.PrimaryDarkBackground else AirShipColors.TextSecondary

            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(AirShipDimens.PillCornerRadius))
                    .background(backgroundColor)
                    .clickable { onOptionSelected(option) }
                    .padding(vertical = 12.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = option.name,
                    color = textColor,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}
