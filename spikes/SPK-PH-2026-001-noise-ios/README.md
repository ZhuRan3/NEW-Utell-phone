# SPK-PH-2026-001 iOS Noise 可行性

> Owner：Zhu3xx
> 关联：Q-PH-2026-017（D4，E2EE 方向 Noise）、TS-PH-2026-001
> 时间盒：1 个工作日
> 状态：本机互操作与 iOS target 编译完成；Connector 共同验收待完成

## 已确认候选

- 首发 Pattern：`Noise_XX_25519_ChaChaPoly_SHA256`（Q-PH-2026-021）。
- 握手角色：Phone = Initiator，Connector = Responder（Q-PH-2026-022）。
- Pattern 选择已确认；本 Spike 仍必须验证实现可用性、跨语言互操作和固定向量，不能以文档确认替代运行证据。

## 假设

iOS 端（Swift，最低 iOS 17）能以**可审计、非自研原语**的方式完成 Noise 握手与 transport 加解密，并与 Rust snow 实现跨语言互操作（同一固定输入产生一致握手结果）。

## 环境

- 本机：macOS + Xcode 26.6 + Swift 6.3.3（2026-08-22 审计）。
- 目标平台：iOS 17+（Spike 先在 macOS 目标跑通向量，再验证 iOS target 编译）。
- 对端参照：Rust snow（Connector 候选实现）。

## 阈值

- 成功：
  1. 候选实现通过至少一组官方/跨语言固定测试向量（Noise_XX_25519_ChaChaPoly_SHA256 优先）。
  2. 与 snow 对同一握手输入产生一致的 handshake hash / transport 密文。
  3. 目标 iOS 17 编译通过；无 GPL 等不兼容许可证。
  4. 私钥不进入日志与 fixture。
- 失败：无维护中实现可用、向量互操作失败、或只能依赖自研 Noise 原语拼装（违反"禁止自创密码"红线）→ 回退评估 libsodium 系方案（Q-PH-2026-017 回滚条件）。
- 需记录：握手各消息 hex、hash、transport 加解密样本、错误/重放拒绝行为。

## 步骤

1. 选择可维护的 Swift Noise 实现，并按已确认的 `Noise_XX_25519_ChaChaPoly_SHA256` 运行。
2. 跑通官方测试向量（`swift test --package-path .build/checkouts/swift-noise --disable-sandbox`）。
3. 起 snow 对端（Rust 小工具）做真实互握。
4. 验证 iOS 17 target 编译。
5. 记录原始结果并回写 D4。

## 原始结果

执行日期：2026-08-24（Asia/Shanghai）。本机 macOS arm64；Xcode 26.6；Swift 6.3.3；Swift Noise `0.1.1`；Swift Crypto `4.5.1`；Rust `snow 0.10.0`。

Swift 宿主运行命令：

```text
swift run --quiet
```

Rust 参照运行命令：

```text
cargo run --quiet
```

Swift 与 Rust snow 输出完全一致：

```text
protocol=Noise_XX_25519_ChaChaPoly_SHA256
msg_0_ciphertext=358072d6365880d1aeea329adf9121383851ed21a28e3b75e965d0d2cd166254
msg_1_ciphertext=64b101b1d0be5a8704bd078f9895001fc03e8e9f9522f188dd128d9846d484663414af878d3e46a2f58911a816d6e8346d4ea17a6f2a0bb4ef4ed56c133cff4560a34e36ea82109f26cf2e5a5caf992b608d55c747f615e5a3425a7a19eefb8f
msg_2_ciphertext=87f864c11ba449f46a0a4f4e2eacbb7b0457784f4fca1937f572c93603e9c4d97e5ea11b16f3968710b23a3be3202dc1b5e1ce3c963347491e74f5c0768a9b42
handshake_hash=9542b10ef534ed52859a8be801ecec0a152d0e03d25fda532218079628357622
transport_ciphertext=af32f233a11c15756c5d7e9efc244a12d8f4e6c051257ea8a6eb641fa51cf24fdc2bb3
transport_plaintext=synthetic-transport
```

Swift 负向检查全部拒绝：`invalid_hex`（奇数长度 `abc`）、`tampered_handshake_message`（msg_1 第 0 字节 XOR `0x01`）、`duplicate_handshake_message`（同一 msg_0 重复提交）和 `tampered_transport_ciphertext`（最后一个密文字节 XOR `0x01`）。这些是库层错误拒绝样本；正式封套的 `uint64` 序号、乱序窗口和跨重连重放策略仍未在本 Spike 中实现。

iOS 17 target 编译通过（产物 `LC_BUILD_VERSION` 的 `platform=2`、`minos=17.0`、`sdk=26.5`）。必须显式指定目标 SDK，避免 SwiftPM 使用宿主 macOS SDK：

```text
swift build -c debug --triple arm64-apple-ios17.0 --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"
swift build -c debug --triple arm64-apple-ios17.0-simulator --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"
```

当前 SwiftPM 链接阶段仍会输出 `using sysroot for 'MacOSX' but targeting 'iPhone'` 警告；产物平台/最低版本检查通过，但这说明正式工程应使用 Xcode 工程的 `xcodebuild` 目标配置，不应把本 Spike 的 SwiftPM 链接命令直接作为发布构建链路。

Swift Noise 上游测试：`101 tests passed, 0 failures`。

本次 Spike 文件 SHA-256：

```text
Package.swift 82ee78cc4811d1d1fd5454a937e317ed8dc6bdd402179dd985b7a5a32494d3ea
Package.resolved f64eae79a5ffa07fe818612fb7ed7f748e249cf5c28df9c74d6d701b02c20df4
Sources/NoiseInteropSpike/main.swift fdbd29cb932dca83027d4dcf8f1716bf4a18a2644fd7e9bac7cfe3a7267f901e
rust/Cargo.toml df4151dc16622ef87707ea834a1db6f846469330e0ea9f41522e57eb4d9a0c3f
rust/Cargo.lock f1619f591117c0bd01e4808eb35554a0814e0c4402167737646135107c78e90f
rust/src/main.rs 30e9632e2df299f42083d09b1c4818014777d0c196290506e5f643f96791ff8c
```

## 解释

- 观察事实：Swift Noise 与 Rust snow 对固定私钥、临时密钥和空握手载荷产生逐字节一致的三条握手消息、握手 hash 和 transport 密文；双方可互相解密 transport 载荷。
- 观察事实：非法 hex、篡改握手消息、重复握手消息和篡改 transport 密文均被拒绝。
- 观察事实：iOS 17 真机和模拟器目标均可编译；宿主默认 SDK 编译命令会产生错误的 macOS/iOS 混用，不能作为验收命令。
- 许可证事实：Swift Noise 为 MIT；Swift Crypto 为 Apache-2.0；Rust snow 为 MIT/Apache-2.0 双许可证，未发现 GPL 依赖。

## 对决策的影响

- 支持：Swift 侧可采用固定版本的非自研 Noise 实现，并继续以 `Noise_XX_25519_ChaChaPoly_SHA256` 作为 Phone/Connector 互操作候选。
- 仍未知：Connector 尚未共同签收向量；正式 transport 封套、序号、重放窗口、超时/错误映射、Keychain 持久化和真机网络恢复尚未验证。
- 门禁：`integration-profile.yaml` 继续保持 `pending`；本 Spike 代码只能作为证据和后续正式测试输入，不得直接复制为生产实现。
