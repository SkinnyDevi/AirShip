use std::{
    net::TcpStream,
    sync::{Arc, Mutex},
    time::Duration,
};

use airship_domain::manifest::PackageManifest;
use airship_primitives::{bytebuffer::ByteBuffer, errors::AirShipError};

use crate::{
    constants::{STREAM_IO_TIMEOUT_SECONDS, TRANSFER_CHUNK_BYTE_SIZE},
    tcp_receiver::ReceivedTcpPackage,
    wire_protocol::{WireFrame, WireFrameKind},
};

pub fn parse_manifest_item_count(payload_bytes: &[u8]) -> Result<usize, AirShipError> {
    let text_payload =
        std::str::from_utf8(payload_bytes).map_err(|error| AirShipError::NetworkFailure {
            message: format!("Invalid UTF-8 manifest offer: {error}"),
        })?;
    let trimmed_text = text_payload.trim();
    if trimmed_text.is_empty() {
        return Err(AirShipError::EmptyPayload);
    }

    Ok(trimmed_text.lines().count())
}

pub fn encode_manifest_offer(manifest: &PackageManifest) -> Vec<u8> {
    let mut lines = Vec::with_capacity(manifest.items().len());
    for item in manifest.items() {
        lines.push(format!(
            "{}\t{}\t{}\t{}",
            item.item_identifier(),
            item.item_name(),
            item.byte_size(),
            item.checksum().as_str()
        ));
    }

    lines.join("\n").into_bytes()
}

pub fn configure_stream_timeouts(stream: &TcpStream) -> Result<(), AirShipError> {
    let timeout = Some(Duration::from_secs(STREAM_IO_TIMEOUT_SECONDS));
    stream
        .set_nonblocking(false)
        .map_err(|error| AirShipError::NetworkFailure {
            message: format!("Failed setting blocking mode: {error}"),
        })?;

    stream
        .set_read_timeout(timeout)
        .map_err(|error| AirShipError::NetworkFailure {
            message: format!("Failed setting read timeout: {error}"),
        })?;

    stream
        .set_write_timeout(timeout)
        .map_err(|error| AirShipError::NetworkFailure {
            message: format!("Failed setting write timeout: {error}"),
        })
}

pub fn receive_single_item_payload(stream: &mut TcpStream) -> Result<Vec<u8>, AirShipError> {
    let header_frame = WireFrame::read_from_stream(stream)?;
    if header_frame.frame_kind() != WireFrameKind::ItemHeader {
        return Err(AirShipError::NetworkFailure {
            message: "Expected item header frame".to_string(),
        });
    }

    let mut collected_bytes = Vec::new();
    loop {
        let next_frame = WireFrame::read_from_stream(stream)?;
        match next_frame.frame_kind() {
            WireFrameKind::ItemChunk => {
                collected_bytes.extend_from_slice(next_frame.payload_bytes())
            }
            WireFrameKind::ItemComplete => return Ok(collected_bytes),
            _ => {
                return Err(AirShipError::NetworkFailure {
                    message: "Unexpected frame during item stream".to_string(),
                });
            }
        }
    }
}

pub fn handle_incoming_connection(
    mut stream: TcpStream,
    received_store: &Arc<Mutex<Vec<ReceivedTcpPackage>>>,
    should_accept: bool,
) -> Result<(), AirShipError> {
    configure_stream_timeouts(&stream)?;
    let offer_frame = WireFrame::read_from_stream(&mut stream)?;
    if offer_frame.frame_kind() != WireFrameKind::ManifestOffer {
        return Err(AirShipError::NetworkFailure {
            message: "First frame must be manifest offer".to_string(),
        });
    }

    let item_count = parse_manifest_item_count(offer_frame.payload_bytes())?;
    let pending_frame = WireFrame::new(WireFrameKind::ManifestPending, b"202".to_vec())?;
    pending_frame.write_to_stream(&mut stream)?;

    if !should_accept {
        let reject_frame = WireFrame::new(WireFrameKind::TransferRejected, b"Declined".to_vec())?;
        return reject_frame.write_to_stream(&mut stream);
    }

    let request_frame = WireFrame::new(WireFrameKind::RequestItems, b"all".to_vec())?;
    request_frame.write_to_stream(&mut stream)?;

    let mut received_items = Vec::with_capacity(item_count);
    for _index in 0..item_count {
        let payload_bytes = receive_single_item_payload(&mut stream)?;
        received_items.push(payload_bytes);
    }
    let complete_frame = WireFrame::new(WireFrameKind::TransferComplete, Vec::new())?;
    complete_frame.write_to_stream(&mut stream)?;

    let mut guard = received_store
        .lock()
        .map_err(|_| AirShipError::StorageFailure {
            message: "Received TCP package store lock poisoned".to_string(),
        })?;
    guard.push(ReceivedTcpPackage {
        item_payloads: received_items,
    });
    Ok(())
}

pub fn stream_payload_chunks(
    stream: &mut TcpStream,
    payload_data: &ByteBuffer,
) -> Result<(), AirShipError> {
    let header_frame = WireFrame::new(
        WireFrameKind::ItemHeader,
        payload_data.len().to_string().into_bytes(),
    )?;
    header_frame.write_to_stream(stream)?;

    let total_chunks = payload_data.len().div_ceil(TRANSFER_CHUNK_BYTE_SIZE).max(1);
    for chunk_index in 0..total_chunks {
        let chunk_slice = if payload_data.is_empty() {
            &[]
        } else {
            payload_data.slice_chunk(chunk_index, TRANSFER_CHUNK_BYTE_SIZE)?
        };
        let chunk_frame = WireFrame::new(WireFrameKind::ItemChunk, chunk_slice.to_vec())?;
        chunk_frame.write_to_stream(stream)?;
    }

    let item_done_frame = WireFrame::new(WireFrameKind::ItemComplete, Vec::new())?;
    item_done_frame.write_to_stream(stream)
}
