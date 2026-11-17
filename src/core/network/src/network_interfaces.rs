use airship_crypto::identity::TlsConfiguration;
use airship_domain::{manifest::PackageManifest, peer_entity::PeerEntity};
use airship_primitives::{bytebuffer::ByteBuffer, errors::AirShipError};

use crate::discover_service_info::DiscoveredServiceInfo;

pub trait MdnsAdvertiser: Send + Sync {
    fn start_advertising(&self, service_info: &DiscoveredServiceInfo) -> Result<(), AirShipError>;
    fn stop_advertising(&self) -> Result<(), AirShipError>;
    fn is_advertising(&self) -> bool;
}

pub trait MdnsBrowser: Send + Sync {
    fn start_discovery(&self) -> Result<(), AirShipError>;
    fn stop_discovery(&self) -> Result<(), AirShipError>;
    fn get_discovered_peers(&self) -> Result<Vec<DiscoveredServiceInfo>, AirShipError>;
}

pub trait UdpBeaconBroadcaster: Send + Sync {
    fn broadcast_beacon(&self, service_info: &DiscoveredServiceInfo) -> Result<(), AirShipError>;
}

pub trait PackageSender: Send + Sync {
    fn send_package(
        &self,
        target_peer: &PeerEntity,
        manifest: &PackageManifest,
        payload_data: &ByteBuffer,
    ) -> Result<u16, AirShipError>;
}

pub trait PackageReceiver: Send + Sync {
    fn bind_and_listen(&self, port: u16, tls_config: &TlsConfiguration)
    -> Result<(), AirShipError>;

    fn stop_listening(&self) -> Result<(), AirShipError>;
}
