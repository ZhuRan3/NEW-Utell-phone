# SPK-PH-2026-002 真机 WSS 生命周期与 Keychain 边界

> Owner：Zhu3xx
> 关联：Q-PH-2026-029（后台不保持长连接）、Q-PH-2026-030/031/032（网络恢复去抖/切换重握手）、Q-PH-2026-023（静态密钥端点安全存储）、TS-PH-2026-001
> 时间盒：1 个工作日
> 状态：已完成（2026-08-28,真机 E3)

## 假设

iOS 真机（iOS 17+）上：①Noise 静态私钥可以 Keychain `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` 安全存储，后台可读、不同步 iCloud、可删除；②URLSessionWebSocketTask 在真实网络上可低延迟建连，后台/前台切换与网络切换后的重连行为可观测，支持「后台不保持长连接、回前台恢复、切网重握手」的已确认语义。

## 环境

- 设备：真机 iPhone（配对可用），iOS 17+；本机 macOS + Xcode 26.6 + Swift 6.3.3。
- 对端：本机 LAN 合成 echo 服务（SPK-SV-2026-001 spike 二进制，`ws://<mac-lan-ip>:18091/ws`，`-echo`）。仅合成数据，无真实业务正文、私钥出设备。
- 说明：ATS 例外仅限本 spike（`NSAllowsLocalNetworking`，LAN 明文）；TLS/WSS 路径在 Relay 正式域名+证书后另行验证。

## 阈值

- 成功：Keychain 写入/读取/删除全过，accessibility 类确为 AfterFirstUnlockThisDeviceOnly、不同步；后台 Keychain 可读；WS 握手 20 次 p50/p95 有记录且无失败；后台返回后旧连接状态与重连延迟有记录；NWPathMonitor 捕获切网事件且切网后握手成功。
- 失败：Keychain 任一断言失败；真机上 WS 无法建连或后台/切网行为与已确认语义矛盾。
- 必留样本：全部测试结果的 JSON 导出（时间戳、延迟分位、系统事件）。

## 步骤

1. xcodegen 生成工程，xcodebuild 真机构建，devicectl 安装启动。
2. App 内自动执行 Keychain 套件（T1）与 WS 延迟/echo（T3）。
3. 引导操作：退后台 10 秒回前台（T2/T4）；关闭再开启 WiFi（T5）。
4. 导出结果 JSON，devicectl 拉回本机，写入证据。

## 原始结果

执行日期：2026-08-28（Asia/Shanghai）。设备：iPhone 17(iPhone18,3)，iOS 26.6.1；本机 macOS + Xcode 26.6，签名 Team 7T8YRHJ263(Apple 开发者账户）；对端为本机 LAN 合成 echo 服务（SPK-SV-2026-001 二进制，`-echo`)。原始导出：`results-2026-08-28.json`。

Keychain 边界（T1/T2，全部通过）：

```text
keychain_roundtrip          PASS  32B roundtrip ok=true
keychain_accessibility      PASS  cku(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
keychain_not_synchronizable PASS  synchronizable=false
keychain_delete             PASS  delete=0 gone=true
keychain_background_read    PASS  write=0 read=0 while backgrounded
```

WSS 生命周期（T3/T4/T5):

```text
ws_handshake_latency          PASS  20次 p50=93.8ms p95=105.9ms max=109.7ms(真机 LAN)
ws_echo_1kib                  PASS  10次1KiB echo p50=11.3ms max=92.3ms
ws_background_survival        FAIL  后台 7.7s 后旧连接已断开(系统挂起,符合预期语义)
ws_reconnect_after_background PASS  重连 254.8ms
ws_after_network_switch       PASS  路径事件=10 次,切网后握手3/3 max=2086.1ms(WiFi 重建窗口)
```

干扰样本：首轮 T3 报 offline,因当时设备 WiFi 处于关闭状态（NWPathMonitor 事件序列佐证），非实现缺陷；WiFi 恢复后重跑通过。

切网事件序列（节选）：`satisfied if=wifi+cellular` → WiFi 关闭 → `satisfied if=cellular` → WiFi 恢复 → `satisfied if=wifi+cellular`,NWPathMonitor 全程捕获。

## 对决策的影响

- 支持 Q-PH-2026-023（端点安全存储）：静态私钥以 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` 存储，往返/属性/不同步/可删除/后台可读全部实证通过。
- 支持 Q-PH-2026-029（后台不保持长连接）：iOS 在后台约 8 秒内挂起 socket（实测 7.7s 断开），系统行为与设计语义一致；回前台重连仅 254.8ms，恢复代价低。
- 支持 Q-PH-2026-030/031/032（网络恢复去抖/切网重握手）:NWPathMonitor 对 WiFi↔蜂窝切换全程可观测，切网恢复后握手 3/3。
- 支持握手超时初始值：真机 LAN 握手 p95≈106ms，相对已确认的 10s 总超时余量充足。
- 仍未知（不得外推）：TLS/WSS 正式路径（待 Relay 域名与证书）、锁屏后 Keychain 行为（WhenUnlocked 对比项未测）、蜂窝/公网直连 Relay 的延迟与稳定性、真实 Noise 会话在真机后台的表现。
- 代码处置：本 spike 工程（xcodegen `project.yml` + 单文件 SwiftUI App）保留在本目录作为可重复验证工具，禁止复制进生产；`SPKPH002.xcodeproj` 为生成物，不入库。
