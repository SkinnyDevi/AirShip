use std::{
    net::{SocketAddr, TcpStream},
    time::Duration,
};

use airship_domain::{manifest::PackageManifest, peer_entity::PeerEntity};
use airship_primitives::{bytebuffer::ByteBuffer, errors::AirShipError};

use crate::{
    constants::STREAM_IO_TIMEOUT_SECONDS,
    network_interfaces::PackageSender,
    tcp_connection::{configure_stream_timeouts, encode_manifest_offer, stream_payload_chunks},
    wire_protocol::{WireFrame, WireFrameKind},
};

pub struct TcpPackageSender {
    target_address: SocketAddr,
}

impl TcpPackageSender {
    pub fn new(target_address: SocketAddr) -> Self {
        Self { target_address }
    }

    pub fn send_package_to_address(
        &self,
        socket_address: SocketAddr,
        manifest: &PackageManifest,
        payload_data: &ByteBuffer,
    ) -> Result<u16, AirShipError> {
        let mut stream = TcpStream::connect_timeout(
            &socket_address,
            Duration::from_secs(STREAM_IO_TIMEOUT_SECONDS),
        )
        .map_err(|error| AirShipError::NetworkFailure {
            message: format!("Failed connecting to peer socket: {error}"),
        })?;
        configure_stream_timeouts(&stream)?;

        let offer_frame = WireFrame::new(
            WireFrameKind::ManifestOffer,
            encode_manifest_offer(manifest),
        )?;
        offer_frame.write_to_stream(&mut stream)?;
        self.drive_transfer_exchange(&mut stream, manifest.items().len(), payload_data)
    }

    fn drive_transfer_exchange(
        &self,
        stream: &mut TcpStream,
        item_count: usize,
        payload_data: &ByteBuffer,
    ) -> Result<u16, AirShipError> {
        let mut observed_status = 200u16;
        loop {
            let incoming_frame = WireFrame::read_from_stream(stream)?;
            match incoming_frame.frame_kind() {
                WireFrameKind::ManifestPending => observed_status = 202,
                WireFrameKind::RequestItems => {
                    for _index in 0..item_count {
                        stream_payload_chunks(stream, payload_data)?;
                    }
                }
                WireFrameKind::TransferComplete => return Ok(observed_status),
                WireFrameKind::TransferRejected => {
                    let reason =
                        String::from_utf8_lossy(incoming_frame.payload_bytes()).to_string();
                    return Err(AirShipError::TransferRejected { reason });
                }
                _ => {
                    return Err(AirShipError::NetworkFailure {
                        message: "Unexpected response frame from receiver".to_string(),
                    });
                }
            }
        }
    }
}

impl PackageSender for TcpPackageSender {
    fn send_package(
        &self,
        _target_peer: &PeerEntity,
        manifest: &PackageManifest,
        payload_data: &ByteBuffer,
    ) -> Result<u16, AirShipError> {
        self.send_package_to_address(self.target_address, manifest, payload_data)
    }
}
