use crate::errors::AirShipError;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ByteBuffer {
    storage: Vec<u8>,
}

impl ByteBuffer {
    pub fn new(storage: Vec<u8>) -> Self {
        Self { storage }
    }

    pub fn empty() -> Self {
        Self {
            storage: Vec::new(),
        }
    }

    pub fn len(&self) -> usize {
        self.storage.len()
    }

    pub fn is_empty(&self) -> bool {
        self.storage.is_empty()
    }

    pub fn as_slice(&self) -> &[u8] {
        &self.storage
    }

    pub fn into_inner(self) -> Vec<u8> {
        self.storage
    }

    pub fn slice_chunk(
        &self,
        chunk_index: usize,
        chunk_size: usize,
    ) -> Result<&[u8], AirShipError> {
        if self.storage.is_empty() {
            return Err(AirShipError::EmptyPayload);
        }

        let total_chunks = self.storage.len().div_ceil(chunk_size);
        if chunk_index >= total_chunks {
            return Err(AirShipError::InvalidChunkIndex {
                requested_index: chunk_index,
                total_chunks,
            });
        }

        let start_offset = chunk_index * chunk_size;
        let end_offset = std::cmp::min(start_offset + chunk_size, self.storage.len());
        Ok(&self.storage[start_offset..end_offset])
    }
}
