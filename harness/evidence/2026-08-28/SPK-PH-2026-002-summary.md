# SPK-PH-2026-002 证据摘要：真机 WSS 生命周期与 Keychain 边界(E3)

日期：2026-08-28（Asia/Shanghai）
状态：真机 E3 完成；不代表公开契约 approved 或生产实现完成。

## 范围

- iOS 真机（iPhone 17,iOS 26.6.1）上验证 Keychain 静态私钥存储边界（写入/读取/属性/不同步/删除/后台可读）。
- 验证真机 WS 握手延迟、echo RTT、后台 socket 存活语义、回前台重连延迟、NWPathMonitor 切网可观测性。
- 不在范围：TLS/WSS 正式路径（待 Relay 域名与证书）、锁屏后 Keychain（WhenUnlocked 对比）、蜂窝/公网直连 Relay、真实 Noise 会话后台行为。

## 环境

- 设备：iPhone 17(iPhone18,3),iOS 26.6.1;本机 macOS + Xcode 26.6;签名 Team 7T8YRHJ263。
- 对端：本机 LAN 合成 echo 服务(SPK-SV-2026-001 spike 二进制,`-echo`);仅合成数据;ATS 例外仅限本 spike(NSAllowsLocalNetworking)。

## 命令

```text
xcodegen && xcodebuild -project SPKPH002.xcodeproj -scheme SPKPH002 \
  -destination 'id=<真机>' -allowProvisioningUpdates build
xcrun devicectl device install app --device <真机> SPKPH002.app
xcrun devicectl device process launch --device <真机> com.zhuran.utellspike.spk002
xcrun devicectl device copy from --domain-type appDataContainer \
  --domain-identifier com.zhuran.utellspike.spk002 \
  --source Documents/spk002_results.json --destination results-2026-08-28.json
```

## 原始结果

完整原始导出：`spikes/SPK-PH-2026-002-device-wss-keychain/results-2026-08-28.json`(11 条结果 + 10 条网络路径事件）。

- Keychain 5/5 通过:32B 往返一致;accessibility=`cku`(AfterFirstUnlockThisDeviceOnly);不同步 iCloud;删除后不可恢复;后台态读写均成功。
- WS 握手 20 次:p50=93.8ms,p95=105.9ms,max=109.7ms(真机 LAN);1KiB echo p50=11.3ms。
- 后台语义:后台 7.7s 旧连接被系统挂起断开;回前台重连 254.8ms。
- 切网:NWPathMonitor 捕获 WiFi↔蜂窝完整序列(10 事件);恢复后握手 3/3。
- 干扰样本:首轮 T3 offline 系设备 WiFi 当时关闭,非实现缺陷,已在 spike README 标注。

## 结论与限制

- 支持:Q-PH-2026-023(Keychain 端点存储)、Q-PH-2026-029(后台不保持长连接——系统行为一致)、Q-PH-2026-030/031/032(切网可观测、恢复后可握手)、10s 握手超时余量充足。
- 限制:LAN 合成对端不代表公网 Relay;TLS 路径未测;锁屏后 Keychain 未测;真实 Noise 会话后台行为未测。
- 门禁:`integration-profile.yaml` 继续保持 `status: pending`。

## 证据文件

- Spike:`spikes/SPK-PH-2026-002-device-wss-keychain/`(README、project.yml、Sources/SpikeApp.swift、results-2026-08-28.json)
- 本摘要:`harness/evidence/2026-08-28/SPK-PH-2026-002-summary.md`
