pub fn validate_hex_character(character: char) -> bool {
    character.is_ascii_hexdigit()
}

pub fn validate_identifier_character(character: char) -> bool {
    character.is_ascii_alphanumeric() || character == '_' || character == '-'
}
