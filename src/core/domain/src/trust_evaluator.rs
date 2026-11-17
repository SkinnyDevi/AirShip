use crate::constants::{HTTP_STATUS_ACCEPTED_PENDING, HTTP_STATUS_OK};
use airship_primitives::errors::AirShipError;

use crate::manifest::PackageManifest;
use crate::peer_entity::PeerEntity;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TransferDecision {
    AutoDownloadDirectly { status_code: u16 },
    RequireManualApproval { status_code: u16 },
}

pub trait TrustEvaluator: Send + Sync {
    fn evaluate_incoming_package(
        &self,
        sender: &PeerEntity,
        manifest: &PackageManifest,
    ) -> Result<TransferDecision, AirShipError>;
}

#[derive(Debug, Default)]
pub struct DefaultTrustEvaluator;

impl DefaultTrustEvaluator {
    pub fn new() -> Self {
        Self
    }
}

impl TrustEvaluator for DefaultTrustEvaluator {
    fn evaluate_incoming_package(
        &self,
        sender: &PeerEntity,
        manifest: &PackageManifest,
    ) -> Result<TransferDecision, AirShipError> {
        if manifest.items().is_empty() {
            return Err(AirShipError::EmptyPayload);
        }

        if sender.is_trusted() {
            Ok(TransferDecision::AutoDownloadDirectly {
                status_code: HTTP_STATUS_OK,
            })
        } else {
            Ok(TransferDecision::RequireManualApproval {
                status_code: HTTP_STATUS_ACCEPTED_PENDING,
            })
        }
    }
}
