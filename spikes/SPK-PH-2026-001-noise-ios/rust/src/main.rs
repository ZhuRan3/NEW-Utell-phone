use snow::{Builder, params::NoiseParams};

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let params: NoiseParams = "Noise_XX_25519_ChaChaPoly_SHA256".parse()?;
    let initiator_static = [
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e,
        0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e,
        0x1f,
    ];
    let responder_static = [
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e,
        0x1f, 0x20,
    ];
    let initiator_ephemeral = [
        0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e,
        0x2f, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e,
        0x3f,
    ];
    let responder_ephemeral = [
        0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f,
        0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x5b, 0x5c, 0x5d, 0x5e, 0x5f,
        0x60,
    ];

    let initiator_builder = Builder::new(params.clone())
        .local_private_key(&initiator_static)?
        .fixed_ephemeral_key_for_testing_only(&initiator_ephemeral);
    let responder_builder = Builder::new(params)
        .local_private_key(&responder_static)?
        .fixed_ephemeral_key_for_testing_only(&responder_ephemeral);
    let mut initiator = initiator_builder.build_initiator()?;
    let mut responder = responder_builder.build_responder()?;
    let mut message = [0_u8; 65535];
    let mut payload = [0_u8; 65535];

    let len0 = initiator.write_message(&[], &mut message)?;
    responder.read_message(&message[..len0], &mut payload)?;
    let message0 = message[..len0].to_vec();

    let len1 = responder.write_message(&[], &mut message)?;
    initiator.read_message(&message[..len1], &mut payload)?;
    let message1 = message[..len1].to_vec();

    let len2 = initiator.write_message(&[], &mut message)?;
    responder.read_message(&message[..len2], &mut payload)?;
    let message2 = message[..len2].to_vec();
    let handshake_hash = initiator.get_handshake_hash().to_vec();

    let mut initiator_transport = initiator.into_transport_mode()?;
    let mut responder_transport = responder.into_transport_mode()?;
    let len = initiator_transport.write_message(b"synthetic-transport", &mut message)?;
    let transport_ciphertext = message[..len].to_vec();
    let plaintext_len = responder_transport.read_message(&message[..len], &mut payload)?;

    println!("protocol=Noise_XX_25519_ChaChaPoly_SHA256");
    println!("msg_0_ciphertext={}", hex(&message0));
    println!("msg_1_ciphertext={}", hex(&message1));
    println!("msg_2_ciphertext={}", hex(&message2));
    println!("handshake_hash={}", hex(&handshake_hash));
    println!("transport_ciphertext={}", hex(&transport_ciphertext));
    println!("transport_plaintext={}", String::from_utf8_lossy(&payload[..plaintext_len]));
    println!("responder_payload_bytes=0");
    Ok(())
}
