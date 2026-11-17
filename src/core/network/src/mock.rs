use std::sync::{
    Arc,
    atomic::{AtomicBool, Ordering},
};

use airship_domain::{manifest::PackageManifest, peer_entity::PeerEntity};
use airship_primitives::{bytebuffer::ByteBuffer, errors::AirShipError};

use crate::{
    discover_service_info::DiscoveredServiceInfo,
    network_interfaces::{MdnsAdvertiser, PackageSender},
};

pub struct MockMdnsAdvertiser {
    active: Arc<AtomicBool>,
}

impl MockMdnsAdvertiser {
    pub fn new() -> Self {
        Self {
            active: Arc::new(AtomicBool::new(false)),
        }
    }
}

impl Default for MockMdnsAdvertiser {
    fn default() -> Self {
        Self::new()
    }
}

impl MdnsAdvertiser for MockMdnsAdvertiser {
    fn start_advertising(&self, _service_info: &DiscoveredServiceInfo) -> Result<(), AirShipError> {
        self.active.store(true, Ordering::SeqCst);
        Ok(())
    }

    fn stop_advertising(&self) -> Result<(), AirShipError> {
        self.active.store(false, Ordering::SeqCst);
        Ok(())
    }

    fn is_advertising(&self) -> bool {
        self.active.load(Ordering::SeqCst)
    }
}

pub struct MockPackageSender;
impl MockPackageSender {
    pub fn new() -> Self {
        Self
    }
}

impl Default for MockPackageSender {
    fn default() -> Self {
        Self::new()
    }
}

impl PackageSender for MockPackageSender {
    fn send_package(
        &self,
        target_peer: &PeerEntity,
        _manifest: &PackageManifest,
        _payload_data: &ByteBuffer,
    ) -> Result<u16, AirShipError> {
        if target_peer.is_trusted() {
            Ok(200)
        } else {
            Ok(202)
        }
    }
}
