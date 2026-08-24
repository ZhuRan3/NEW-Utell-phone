# SPK-PH-2026-001 Phone Noise 证据摘要

日期：2026-08-24（Asia/Shanghai）
环境：macOS arm64，Xcode 26.6，Swift 6.3.3，Rust snow 0.10.0。

## 结果

- Swift Noise 上游测试：101 passed，0 failures。
- Swift 与 Rust snow 固定输入：三条握手消息、handshake hash、transport ciphertext 逐字节一致。
- Swift transport 由 Initiator 加密、Responder 解密成功。
- 非法 hex、篡改握手、重复握手、篡改 transport 均拒绝。
- iOS 17 device 与 simulator target 编译通过。

## 可复现命令

```text
cd spikes/SPK-PH-2026-001-noise-ios
swift run --quiet
cargo run --quiet --manifest-path rust/Cargo.toml
swift build -c debug --triple arm64-apple-ios17.0 --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"
swift build -c debug --triple arm64-apple-ios17.0-simulator --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"
```

完整向量、失败样本、解释和文件校验和见同目录 `README.md`。

证据生成时两端 `harness/契约/integration-profile.yaml` SHA-256：`1807d8c9b86149f6d80ee38a29539b08e31ae17a5491b604d7656b39e8230998`。

## 门禁结论

本证据支持进入 Connector 共同验收，不支持将 `integration-profile.yaml` 改为 `approved`。正式契约仍缺 transport envelope、序号/重放窗口、错误映射、Keychain 和真机生命周期证据。
