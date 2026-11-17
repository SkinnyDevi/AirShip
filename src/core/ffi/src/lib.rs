//! Thin UniFFI boundary exposing thread-safe controllers and callbacks to Swift and Kotlin.

pub mod controller;
pub mod data_models;

// -----------------------------------------------------------------------------
// 3. Unit Tests
// -----------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use airship_primitives::errors::AirShipError;

    use crate::controller::AirShipCoreController;

    #[test]
    fn test_controller_initialization_and_identity() -> Result<(), AirShipError> {
        let controller = AirShipCoreController::new("DEV_USER")?;
        assert_eq!(controller.get_local_user_name_id(), "USER_DEV_USER");
        assert_eq!(controller.get_local_fingerprint().len(), 64);
        assert!(!controller.is_broadcasting());

        controller.start_broadcasting_presence()?;
        assert!(controller.is_broadcasting());

        controller.stop_broadcasting_presence()?;
        assert!(!controller.is_broadcasting());
        Ok(())
    }

    #[test]
    fn test_controller_peer_management() -> Result<(), AirShipError> {
        let controller = AirShipCoreController::new("DEV_USER")?;
        let test_fingerprint = "1".repeat(64);
        controller.add_peer("USER_REMOTE", "Remote User", &test_fingerprint, false)?;

        let peers = controller.list_all_peers()?;
        assert_eq!(peers.len(), 1);
        assert_eq!(peers[0].is_trusted, false);

        controller.set_peer_trust_status("USER_REMOTE", true)?;
        let updated_peers = controller.list_all_peers()?;
        assert_eq!(updated_peers[0].is_trusted, true);

        let removed = controller.remove_peer("USER_REMOTE")?;
        assert!(removed);
        assert_eq!(controller.list_all_peers()?.len(), 0);
        Ok(())
    }
}
