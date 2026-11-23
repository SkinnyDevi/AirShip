import CryptoKit
import Foundation

#if canImport(UIKit)
	import UIKit
#endif

public enum IdentityStorageKeys {
	public static let defaultSuiteName = "com.skdvcsm.airship.identity"
	internal static let privateKeyBase64 = "airship.identity.ed25519.privateKey"
	internal static let displayAlias = "airship.identity.displayAlias"
}

public struct LocalDeviceIdentity: Equatable, Sendable {
	public let userNameId: String
	public let displayAlias: String
	public let fingerprintHex: String
	public let publicKeyBytes: Data

	public init(
		userNameId: String,
		displayAlias: String,
		fingerprintHex: String,
		publicKeyBytes: Data
	) {
		self.userNameId = userNameId
		self.displayAlias = displayAlias
		self.fingerprintHex = fingerprintHex
		self.publicKeyBytes = publicKeyBytes
	}
}

public protocol DeviceIdentityStoring: Sendable {
	func loadOrCreateIdentity() -> LocalDeviceIdentity
	func updateDisplayAlias(_ alias: String) -> LocalDeviceIdentity
	func regenerateIdentity() -> LocalDeviceIdentity
}

private func computePublicKeyFingerprintHex(_ publicKeyBytes: Data) -> String {
	let digest = SHA256.hash(data: publicKeyBytes)
	return digest.map { String(format: "%02x", $0) }.joined()
}

private func deriveUserNameId(from fingerprintHex: String) -> String {
	return "USER_\(fingerprintHex.prefix(8).uppercased())"
}

private func defaultDeviceAlias(for userNameId: String) -> String {
	let suffix = String(userNameId.suffix(4))
	#if canImport(UIKit)
		let rawDeviceName = resolveCurrentUIKitDeviceName()
		let trimmedName = rawDeviceName.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmedName.isEmpty || trimmedName == "iPhone" || trimmedName == "iPad" {
			let baseLabel = trimmedName.isEmpty ? "iPhone" : trimmedName
			return "\(baseLabel) (\(suffix))"
		}
		return trimmedName
	#else
		let hostName = Host.current().localizedName ?? "Mac"
		let trimmedHost = hostName.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmedHost.isEmpty ? "AirShip (\(suffix))" : trimmedHost
	#endif
}

#if canImport(UIKit)
	private func resolveCurrentUIKitDeviceName() -> String {
		if Thread.isMainThread {
			return MainActor.assumeIsolated { UIDevice.current.name }
		}
		return DispatchQueue.main.sync {
			UIDevice.current.name
		}
	}
#endif

public final class UserDefaultsIdentityStore: DeviceIdentityStoring, @unchecked Sendable {
	private let lock = NSLock()
	private let defaultsSuiteName: String

	public init(suiteName: String = IdentityStorageKeys.defaultSuiteName) {
		self.defaultsSuiteName = suiteName
	}

	public func loadOrCreateIdentity() -> LocalDeviceIdentity {
		lock.withLock {
			let defaults = resolvedUserDefaults()
			let privateKey = loadOrCreatePrivateKey(in: defaults)
			return buildIdentity(from: privateKey, defaults: defaults)
		}
	}

	public func updateDisplayAlias(_ alias: String) -> LocalDeviceIdentity {
		lock.withLock {
			let defaults = resolvedUserDefaults()
			let privateKey = loadOrCreatePrivateKey(in: defaults)
			let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
			if !trimmedAlias.isEmpty {
				defaults.set(trimmedAlias, forKey: IdentityStorageKeys.displayAlias)
			}
			return buildIdentity(from: privateKey, defaults: defaults)
		}
	}

	public func regenerateIdentity() -> LocalDeviceIdentity {
		lock.withLock {
			let defaults = resolvedUserDefaults()
			let freshKey = Curve25519.Signing.PrivateKey()
			persistPrivateKey(freshKey, in: defaults)
			return buildIdentity(from: freshKey, defaults: defaults)
		}
	}

	private func resolvedUserDefaults() -> UserDefaults {
		return UserDefaults(suiteName: defaultsSuiteName) ?? .standard
	}

	private func loadOrCreatePrivateKey(in defaults: UserDefaults) -> Curve25519.Signing.PrivateKey {
		if let encoded = defaults.string(forKey: IdentityStorageKeys.privateKeyBase64),
			let rawBytes = Data(base64Encoded: encoded),
			let restored = try? Curve25519.Signing.PrivateKey(rawRepresentation: rawBytes)
		{
			return restored
		}
		let generated = Curve25519.Signing.PrivateKey()
		persistPrivateKey(generated, in: defaults)
		return generated
	}

	private func persistPrivateKey(
		_ privateKey: Curve25519.Signing.PrivateKey,
		in defaults: UserDefaults
	) {
		let encoded = privateKey.rawRepresentation.base64EncodedString()
		defaults.set(encoded, forKey: IdentityStorageKeys.privateKeyBase64)
	}

	private func buildIdentity(
		from privateKey: Curve25519.Signing.PrivateKey,
		defaults: UserDefaults
	) -> LocalDeviceIdentity {
		let publicBytes = privateKey.publicKey.rawRepresentation
		let fingerprintHex = computePublicKeyFingerprintHex(publicBytes)
		let userNameId = deriveUserNameId(from: fingerprintHex)
		let storedAlias = defaults.string(forKey: IdentityStorageKeys.displayAlias)?
			.trimmingCharacters(in: .whitespacesAndNewlines)
		let resolvedAlias: String
		if let storedAlias, !storedAlias.isEmpty {
			resolvedAlias = storedAlias
		} else {
			resolvedAlias = defaultDeviceAlias(for: userNameId)
			defaults.set(resolvedAlias, forKey: IdentityStorageKeys.displayAlias)
		}
		return LocalDeviceIdentity(
			userNameId: userNameId,
			displayAlias: resolvedAlias,
			fingerprintHex: fingerprintHex,
			publicKeyBytes: publicBytes
		)
	}
}
