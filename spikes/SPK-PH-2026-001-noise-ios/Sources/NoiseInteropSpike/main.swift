import Crypto
import Foundation
import Noise

enum SpikeError: Error {
    case invalidHex
    case missingCipherState
    case unexpectedSuccess(String)
}

func bytes(_ hex: String) throws -> [UInt8] {
    guard hex.count.isMultiple(of: 2) else { throw SpikeError.invalidHex }
    return try stride(from: 0, to: hex.count, by: 2).map { offset in
        let start = hex.index(hex.startIndex, offsetBy: offset)
        let end = hex.index(start, offsetBy: 2)
        guard let value = UInt8(hex[start..<end], radix: 16) else { throw SpikeError.invalidHex }
        return value
    }
}

func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
}

let initiatorStatic = try Curve25519.KeyAgreement.PrivateKey(
    rawRepresentation: bytes("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
)
let responderStatic = try Curve25519.KeyAgreement.PrivateKey(
    rawRepresentation: bytes("0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20")
)
let initiatorEphemeral = try Curve25519.KeyAgreement.PrivateKey(
    rawRepresentation: bytes("202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f")
)
let responderEphemeral = try Curve25519.KeyAgreement.PrivateKey(
    rawRepresentation: bytes("4142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f60")
)

let suite = Noise.CipherSuite(
    keyCurve: .x25519,
    cipher: .ChaChaPoly1305,
    hashFunction: .sha256
)
let initiatorConfig = Noise.Config(
    cipherSuite: suite,
    handshake: .XX_Initiator,
    staticKeypair: initiatorStatic,
    ephemeralKeypair: initiatorEphemeral
)
let responderConfig = Noise.Config(
    cipherSuite: suite,
    handshake: .XX_Responder,
    staticKeypair: responderStatic,
    ephemeralKeypair: responderEphemeral
)
let initiator = try Noise.HandshakeState(config: initiatorConfig)
let responder = try Noise.HandshakeState(config: responderConfig)

let message0 = try initiator.writeMessage(payload: []).buffer
let responderRead1 = try responder.readMessage(message0)
let message1 = try responder.writeMessage(payload: []).buffer
let initiatorRead2 = try initiator.readMessage(message1)
let message2Result = try initiator.writeMessage(payload: [])
let message2 = message2Result.buffer
let responderRead3 = try responder.readMessage(message2)

guard let initiatorSend = message2Result.c1, let responderReceive = responderRead3.c1 else {
    throw SpikeError.missingCipherState
}
let transportPayload = Array("synthetic-transport".utf8)
let transportCiphertext = try initiatorSend.encrypt(plaintext: transportPayload)
let transportPlaintext = try responderReceive.decrypt(ciphertext: transportCiphertext)

print("protocol=\(initiator.protocolName)")
print("msg_0_ciphertext=\(hex(message0))")
print("msg_1_ciphertext=\(hex(message1))")
print("msg_2_ciphertext=\(hex(message2))")
print("handshake_hash=\(hex(initiator.channelBinding()))")
print("transport_ciphertext=\(hex(transportCiphertext))")
print("transport_plaintext=\(String(bytes: transportPlaintext, encoding: .utf8) ?? "<invalid>")")
print("responder_payload_bytes=\(responderRead1.payload.count + initiatorRead2.payload.count + responderRead3.payload.count)")

func expectFailure(_ label: String, _ operation: () throws -> Void) throws {
    do {
        try operation()
        throw SpikeError.unexpectedSuccess(label)
    } catch SpikeError.unexpectedSuccess {
        throw SpikeError.unexpectedSuccess(label)
    } catch {
        print("negative_\(label)=rejected")
    }
}

try expectFailure("invalid_hex") {
    _ = try bytes("abc")
}

try expectFailure("tampered_handshake_message") {
    let tampered = message1.enumerated().map { index, byte in
        index == 0 ? byte ^ 0x01 : byte
    }
    let freshInitiator = try Noise.HandshakeState(config: initiatorConfig)
    let freshResponder = try Noise.HandshakeState(config: responderConfig)
    let freshMessage0 = try freshInitiator.writeMessage(payload: []).buffer
    _ = try freshResponder.readMessage(freshMessage0)
    _ = try freshInitiator.readMessage(tampered)
}

try expectFailure("duplicate_handshake_message") {
    let freshResponder = try Noise.HandshakeState(config: responderConfig)
    _ = try freshResponder.readMessage(message0)
    _ = try freshResponder.readMessage(message0)
}

try expectFailure("tampered_transport_ciphertext") {
    let freshInitiator = try Noise.HandshakeState(config: initiatorConfig)
    let freshResponder = try Noise.HandshakeState(config: responderConfig)
    let freshMessage0 = try freshInitiator.writeMessage(payload: []).buffer
    _ = try freshResponder.readMessage(freshMessage0)
    let freshMessage1 = try freshResponder.writeMessage(payload: []).buffer
    _ = try freshInitiator.readMessage(freshMessage1)
    let freshMessage2Result = try freshInitiator.writeMessage(payload: [])
    let freshResponderRead3 = try freshResponder.readMessage(freshMessage2Result.buffer)
    guard let send = freshMessage2Result.c1, let receive = freshResponderRead3.c1 else {
        throw SpikeError.missingCipherState
    }
    var tampered = try send.encrypt(plaintext: transportPayload)
    tampered[tampered.count - 1] ^= 0x01
    _ = try receive.decrypt(ciphertext: tampered)
}
