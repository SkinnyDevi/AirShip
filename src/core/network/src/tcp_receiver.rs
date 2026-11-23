use std::{
    io::ErrorKind,
    net::{IpAddr, Ipv4Addr, SocketAddr, TcpListener},
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
    },
    thread::{self, JoinHandle},
    time::Duration,
};

use airship_crypto::identity::TlsConfiguration;
use airship_primitives::errors::AirShipError;

use crate::{
    constants::ACCEPT_POLL_INTERVAL_MS, network_interfaces::PackageReceiver,
    tcp_connection::handle_incoming_connection,
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReceivedTcpPackage {
    pub item_payloads: Vec<Vec<u8>>,
}

pub struct TcpPackageReceiver {
    is_listening: Arc<AtomicBool>,
    should_accept: Arc<AtomicBool>,
    bound_port: Arc<Mutex<Option<u16>>>,
    received_packages: Arc<Mutex<Vec<ReceivedTcpPackage>>>,
    worker_handle: Mutex<Option<JoinHandle<()>>>,
}

impl TcpPackageReceiver {
    pub fn new(should_accept: bool) -> Self {
        Self {
            is_listening: Arc::new(AtomicBool::new(false)),
            should_accept: Arc::new(AtomicBool::new(should_accept)),
            bound_port: Arc::new(Mutex::new(None)),
            received_packages: Arc::new(Mutex::new(Vec::new())),
            worker_handle: Mutex::new(None),
        }
    }

    pub fn bind_socket_address(&self, socket_address: SocketAddr) -> Result<u16, AirShipError> {
        let listener =
            TcpListener::bind(socket_address).map_err(|error| AirShipError::NetworkFailure {
                message: format!("Failed binding TCP listener: {error}"),
            })?;
        listener
            .set_nonblocking(true)
            .map_err(|error| AirShipError::NetworkFailure {
                message: format!("Failed setting listener nonblocking: {error}"),
            })?;

        let assigned_port = listener
            .local_addr()
            .map_err(|error| AirShipError::NetworkFailure {
                message: format!("Failed reading local listener address: {error}"),
            })?
            .port();

        self.store_bound_port(Some(assigned_port))?;
        self.is_listening.store(true, Ordering::SeqCst);
        self.spawn_accept_loop(listener)?;
        Ok(assigned_port)
    }

    pub fn bound_port(&self) -> Result<Option<u16>, AirShipError> {
        let guard = self
            .bound_port
            .lock()
            .map_err(|_| AirShipError::StorageFailure {
                message: "Bound port lock poisoned".to_string(),
            })?;
        Ok(*guard)
    }

    pub fn received_packages(&self) -> Result<Vec<ReceivedTcpPackage>, AirShipError> {
        let guard = self
            .received_packages
            .lock()
            .map_err(|_| AirShipError::StorageFailure {
                message: "Received packages lock poisoned".to_string(),
            })?;
        Ok(guard.clone())
    }

    fn store_bound_port(&self, port: Option<u16>) -> Result<(), AirShipError> {
        let mut guard = self
            .bound_port
            .lock()
            .map_err(|_| AirShipError::StorageFailure {
                message: "Bound port lock poisoned".to_string(),
            })?;
        *guard = port;
        Ok(())
    }

    fn spawn_accept_loop(&self, listener: TcpListener) -> Result<(), AirShipError> {
        let active_flag = Arc::clone(&self.is_listening);
        let accept_flag = Arc::clone(&self.should_accept);
        let received_store = Arc::clone(&self.received_packages);

        let handle = thread::spawn(move || {
            while active_flag.load(Ordering::SeqCst) {
                match listener.accept() {
                    Ok((stream, _peer_address)) => {
                        let _ = handle_incoming_connection(
                            stream,
                            &received_store,
                            accept_flag.load(Ordering::SeqCst),
                        );
                    }
                    Err(error) if error.kind() == ErrorKind::WouldBlock => {
                        thread::sleep(Duration::from_millis(ACCEPT_POLL_INTERVAL_MS));
                    }
                    Err(_) => break,
                }
            }
        });

        let mut handle_guard =
            self.worker_handle
                .lock()
                .map_err(|_| AirShipError::StorageFailure {
                    message: "Worker handle lock poisoned".to_string(),
                })?;
        *handle_guard = Some(handle);
        Ok(())
    }
}

impl PackageReceiver for TcpPackageReceiver {
    fn bind_and_listen(
        &self,
        port: u16,
        _tls_config: &TlsConfiguration,
    ) -> Result<(), AirShipError> {
        let socket_address = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), port);
        let _assigned_port = self.bind_socket_address(socket_address)?;
        Ok(())
    }

    fn stop_listening(&self) -> Result<(), AirShipError> {
        self.is_listening.store(false, Ordering::SeqCst);
        let mut handle_guard =
            self.worker_handle
                .lock()
                .map_err(|_| AirShipError::StorageFailure {
                    message: "Worker handle lock poisoned".to_string(),
                })?;

        if let Some(handle) = handle_guard.take() {
            let _ = handle.join();
        }

        self.store_bound_port(None)
    }
}
