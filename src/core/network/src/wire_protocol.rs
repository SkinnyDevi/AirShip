use std::io::{Read, Write};

use crate::constants::{MAX_WIRE_FRAME_PAYLOAD_BYTES, WIRE_HEADER_BYTE_LENGTH};
use airship_primitives::errors::AirShipError;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum WireFrameKind {
    ManifestOffer = 0x01,
    ManifestPending = 0x02,
    RequestItems = 0x03,
    ItemHeader = 0x04,
    ItemChunk = 0x05,
    ItemComplete = 0x06,
    TransferComplete = 0x07,
    TransferRejected = 0x08,
    TransferError = 0x09,
}

impl TryFrom<u8> for WireFrameKind {
    type Error = AirShipError;

    fn try_from(raw_byte: u8) -> Result<Self, Self::Error> {
        match raw_byte {
            0x01 => Ok(Self::ManifestOffer),
            0x02 => Ok(Self::ManifestPending),
            0x03 => Ok(Self::RequestItems),
            0x04 => Ok(Self::ItemHeader),
            0x05 => Ok(Self::ItemChunk),
            0x06 => Ok(Self::ItemComplete),
            0x07 => Ok(Self::TransferComplete),
            0x08 => Ok(Self::TransferRejected),
            0x09 => Ok(Self::TransferError),
            _ => Err(AirShipError::NetworkFailure {
                message: format!("Unknown wire frame kind: 0x{raw_byte:02x}"),
            }),
        }
    }
}

fn validate_payload_length(byte_count: usize) -> Result<u32, AirShipError> {
    let payload_length = u32::try_from(byte_count).map_err(|_| AirShipError::NetworkFailure {
        message: "Wire frame payload exceeds u32 bounds".to_string(),
    })?;
    if payload_length > MAX_WIRE_FRAME_PAYLOAD_BYTES {
        return Err(AirShipError::NetworkFailure {
            message: format!("Wire frame payload too large: {payload_length} bytes"),
        });
    }
    Ok(payload_length)
}

fn decode_wire_header(
    header_bytes: [u8; WIRE_HEADER_BYTE_LENGTH],
) -> Result<(WireFrameKind, usize), AirShipError> {
    let frame_kind = WireFrameKind::try_from(header_bytes[0])?;
    let length_bytes = [
        header_bytes[1],
        header_bytes[2],
        header_bytes[3],
        header_bytes[4],
    ];
    let payload_length = u32::from_be_bytes(length_bytes);
    if payload_length > MAX_WIRE_FRAME_PAYLOAD_BYTES {
        return Err(AirShipError::NetworkFailure {
            message: format!("Incoming frame exceeds limit: {payload_length} bytes"),
        });
    }
    Ok((frame_kind, payload_length as usize))
}

fn map_io_error(context_label: &str, io_error: std::io::Error) -> AirShipError {
    AirShipError::NetworkFailure {
        message: format!("{context_label}: {io_error}"),
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WireFrame {
    frame_kind: WireFrameKind,
    payload_bytes: Vec<u8>,
}

impl WireFrame {
    pub fn new(frame_kind: WireFrameKind, payload_bytes: Vec<u8>) -> Result<Self, AirShipError> {
        let _validated_length = validate_payload_length(payload_bytes.len())?;
        Ok(Self {
            frame_kind,
            payload_bytes,
        })
    }

    pub fn frame_kind(&self) -> WireFrameKind {
        self.frame_kind
    }

    pub fn payload_bytes(&self) -> &[u8] {
        &self.payload_bytes
    }

    pub fn encode_header(&self) -> Result<[u8; WIRE_HEADER_BYTE_LENGTH], AirShipError> {
        let payload_length = validate_payload_length(self.payload_bytes.len())?;
        let length_bytes = payload_length.to_be_bytes();
        Ok([
            self.frame_kind as u8,
            length_bytes[0],
            length_bytes[1],
            length_bytes[2],
            length_bytes[3],
        ])
    }

    pub fn write_to_stream<W: Write>(&self, writer: &mut W) -> Result<(), AirShipError> {
        let header_bytes = self.encode_header()?;
        writer
            .write_all(&header_bytes)
            .map_err(|error| map_io_error("Failed writing frame header", error))?;
        if !self.payload_bytes.is_empty() {
            writer
                .write_all(&self.payload_bytes)
                .map_err(|error| map_io_error("Failed writing frame payload", error))?;
        }
        writer
            .flush()
            .map_err(|error| map_io_error("Failed flushing frame stream", error))
    }

    pub fn read_from_stream<R: Read>(reader: &mut R) -> Result<Self, AirShipError> {
        let mut header_bytes = [0u8; WIRE_HEADER_BYTE_LENGTH];
        reader
            .read_exact(&mut header_bytes)
            .map_err(|error| map_io_error("Failed reading frame header", error))?;
        let (frame_kind, payload_length) = decode_wire_header(header_bytes)?;
        let mut payload_bytes = vec![0u8; payload_length];
        if payload_length > 0 {
            reader
                .read_exact(&mut payload_bytes)
                .map_err(|error| map_io_error("Failed reading frame payload", error))?;
        }
        Ok(Self {
            frame_kind,
            payload_bytes,
        })
    }
}
