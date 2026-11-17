use crate::errors::AirShipError;
use crate::hex::validate_identifier_character;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct PeerId {
    raw_identifier: String,
}

impl PeerId {
    pub fn new(raw_identifier: String) -> Result<Self, AirShipError> {
        if raw_identifier.is_empty() {
            return Err(AirShipError::InvalidIdentifier {
                reason: "Peer identifier cannot be empty".to_string(),
            });
        }
        let valid_characters = raw_identifier.chars().all(validate_identifier_character);
        if !valid_characters {
            return Err(AirShipError::InvalidIdentifier {
                reason: "Peer identifier contains invalid characters".to_string(),
            });
        }
        Ok(Self { raw_identifier })
    }

    pub fn as_str(&self) -> &str {
        &self.raw_identifier
    }
}
