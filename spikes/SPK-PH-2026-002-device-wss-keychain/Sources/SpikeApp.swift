import SwiftUI
import Security
import Network
import UIKit

// SPK-PH-2026-002 真机 WSS 生命周期与 Keychain 边界验证。
// Spike 专用合成测试,非生产代码;仅合成数据,无私钥出设备。

struct TResult: Codable {
    let name: String
    let passed: Bool
    let detail: String
    let at: String
}

func nowISO() -> String { ISO8601DateFormatter().string(from: Date()) }

@MainActor
final class Runner: ObservableObject {
    @Published var lines: [String] = []
    var results: [TResult] = []
    var pathEvents: [String] = []
    let host = "192.168.1.10"
    let port = 18091
    var lifecycleTask: URLSessionWebSocketTask?
    var lastBackgroundAt: Date?
    var monitor: NWPathMonitor?

    func say(_ s: String) { lines.append("\(nowISO())  \(s)") }

    func record(_ name: String, _ passed: Bool, _ detail: String) {
        results.append(TResult(name: name, passed: passed, detail: detail, at: nowISO()))
        say("\(passed ? "PASS" : "FAIL") \(name): \(detail)")
    }

    // MARK: T1 Keychain 边界
    func testKeychain() {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: "com.zhuran.utellspike.spk002",
                                   kSecAttrAccount as String: "noise-static-key"]
        SecItemDelete(base as CFDictionary)
        let secret = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        var add = base
        add[kSecValueData as String] = secret
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            record("keychain_write", false, "SecItemAdd status=\(addStatus)")
            return
        }
        var query = base
        query[kSecReturnData as String] = true
        query[kSecReturnAttributes as String] = true
        var item: CFTypeRef?
        let readStatus = SecItemCopyMatching(query as CFDictionary, &item)
        guard readStatus == errSecSuccess, let dict = item as? [String: Any],
              let data = dict[kSecValueData as String] as? Data else {
            record("keychain_read", false, "SecItemCopyMatching status=\(readStatus)")
            return
        }
        record("keychain_roundtrip", data == secret, "32B roundtrip ok=\(data == secret)")
        let accessible = dict[kSecAttrAccessible as String] as? String ?? "unknown"
        record("keychain_accessibility", accessible == String(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly), accessible)
        let syncable = dict[kSecAttrSynchronizable as String] as? Bool ?? false
        record("keychain_not_synchronizable", !syncable, "synchronizable=\(syncable)")
        let del = SecItemDelete(base as CFDictionary)
        var verify = base
        verify[kSecReturnData as String] = true
        let gone = SecItemCopyMatching(verify as CFDictionary, nil) == errSecItemNotFound
        record("keychain_delete", del == errSecSuccess && gone, "delete=\(del) gone=\(gone)")
    }

    // MARK: T2 后台 Keychain 可读性(scenePhase .background 时调用)
    func keychainBackgroundRead() {
        var bg: UIBackgroundTaskIdentifier = .invalid
        bg = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(bg); bg = .invalid
        }
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: "com.zhuran.utellspike.spk002",
                                   kSecAttrAccount as String: "bg-read"]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data("bg".utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let w = SecItemAdd(add as CFDictionary, nil)
        var query = base
        query[kSecReturnData as String] = true
        var item: CFTypeRef?
        let r = SecItemCopyMatching(query as CFDictionary, &item)
        record("keychain_background_read", w == errSecSuccess && r == errSecSuccess,
               "write=\(w) read=\(r) while backgrounded")
        SecItemDelete(base as CFDictionary)
        UIApplication.shared.endBackgroundTask(bg)
    }

    // MARK: WS 基础
    func wsURL() -> URL { URL(string: "ws://\(host):\(port)/ws")! }

    private func pingOnce() async throws -> Double {
        let t0 = Date()
        let task = URLSession.shared.webSocketTask(with: wsURL())
        task.resume()
        defer { task.cancel() }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            task.sendPing { err in
                if let err { cont.resume(throwing: err) } else { cont.resume() }
            }
        }
        return Date().timeIntervalSince(t0) * 1000
    }

    // MARK: T3 握手延迟 ×20 + echo RTT ×10
    func testLatency() async {
        say("T3 开始:20 次握手到 \(host):\(port)")
        var lat: [Double] = []
        for _ in 0..<20 {
            do { lat.append(try await pingOnce()) }
            catch { record("ws_handshake_latency", false, error.localizedDescription); return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        lat.sort()
        let p50 = lat[lat.count / 2]
        let p95 = lat[Int(ceil(0.95 * Double(lat.count))) - 1]
        record("ws_handshake_latency", true,
               String(format: "20次 p50=%.1fms p95=%.1fms max=%.1fms", p50, p95, lat.last ?? 0))

        let payload = Data(repeating: 0x61, count: 1024)
        var rtts: [Double] = []
        let task = URLSession.shared.webSocketTask(with: wsURL())
        task.resume()
        defer { task.cancel() }
        for _ in 0..<10 {
            let t0 = Date()
            do {
                try await task.send(.data(payload))
                _ = try await task.receive()
                rtts.append(Date().timeIntervalSince(t0) * 1000)
            } catch {
                record("ws_echo_1kib", false, error.localizedDescription)
                return
            }
        }
        rtts.sort()
        record("ws_echo_1kib", true,
               String(format: "10次1KiB echo p50=%.1fms max=%.1fms", rtts[rtts.count / 2], rtts.last ?? 0))
        say("T3 完成")
    }

    // MARK: T4 前后台生命周期
    func beginLifecycle() {
        lifecycleTask?.cancel()
        let task = URLSession.shared.webSocketTask(with: wsURL())
        task.resume()
        lifecycleTask = task
        say("T4 已建立常连。请按 Home 手势退到后台约 10 秒,再回到 App")
    }

    func noteBackground() {
        lastBackgroundAt = Date()
        keychainBackgroundRead()
        say("已进入后台(T2 后台 Keychain 读写已执行)")
    }

    func onForeground() {
        guard let bgAt = lastBackgroundAt, lifecycleTask != nil else { return }
        lastBackgroundAt = nil
        let gap = Date().timeIntervalSince(bgAt)
        lifecycleTask?.sendPing { [weak self] err in
            Task { @MainActor [weak self] in
                self?.record("ws_background_survival", err == nil,
                             String(format: "后台 %.1fs 后旧连接%@", gap, err == nil ? "仍可用" : "已断开"))
            }
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let ms = try await self.pingOnce()
                self.record("ws_reconnect_after_background", true, String(format: "重连 %.1fms", ms))
            } catch {
                self.record("ws_reconnect_after_background", false, error.localizedDescription)
            }
        }
    }

    // MARK: T5 切网(NWPathMonitor 常驻,切网后手动握手 ×3)
    func startMonitorIfNeeded() {
        guard monitor == nil else { return }
        let m = NWPathMonitor()
        m.pathUpdateHandler = { [weak self] path in
            let kinds = path.availableInterfaces.map {
                $0.type == .wifi ? "wifi" : $0.type == .cellular ? "cellular" : "other"
            }.joined(separator: "+")
            let line = "\(nowISO()) status=\(path.status) if=\(kinds)"
            Task { @MainActor [weak self] in
                self?.pathEvents.append(line)
                self?.say("网络路径: \(path.status) [\(kinds)]")
            }
        }
        m.start(queue: .global(qos: .utility))
        monitor = m
        say("T5 路径监听已开启。请从控制中心关闭 WiFi 约 5 秒再开启,然后点「切网后握手」")
    }

    func testAfterSwitch() async {
        let changed = pathEvents.count
        var lat: [Double] = []
        for _ in 0..<3 {
            do { lat.append(try await pingOnce()) }
            catch { record("ws_after_network_switch", false, error.localizedDescription); return }
        }
        record("ws_after_network_switch", changed >= 1 && lat.count == 3,
               String(format: "路径事件=%d 次,切网后握手3/3 max=%.1fms", changed, lat.max() ?? 0))
    }

    // MARK: 导出
    func export() -> URL? {
        struct Export: Codable { let spike: String; let device: String; let results: [TResult]; let path_events: [String] }
        let payload = Export(spike: "SPK-PH-2026-002",
                             device: "\(UIDevice.current.model) \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
                             results: results, path_events: pathEvents)
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("spk002_results.json")
        do {
            try JSONEncoder().encode(payload).write(to: url)
            say("结果已写入 \(url.lastPathComponent)(共 \(results.count) 条)")
            return url
        } catch {
            say("导出失败: \(error.localizedDescription)")
            return nil
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var runner: Runner
    var body: some View {
        VStack(spacing: 12) {
            Text("SPK-PH-2026-002 真机验证").font(.headline)
            HStack {
                Button("T1 Keychain") { runner.testKeychain() }
                Button("T3 延迟/Echo") { Task { await runner.testLatency() } }
            }
            HStack {
                Button("T4 前后台") { runner.beginLifecycle() }
                Button("T5 切网监听") { runner.startMonitorIfNeeded() }
                Button("切网后握手") { Task { await runner.testAfterSwitch() } }
            }
            Button("导出结果") { _ = runner.export() }
            ScrollView {
                Text(runner.lines.reversed().joined(separator: "\n"))
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }
}

@main
struct SpikeApp: App {
    @StateObject private var runner = Runner()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(runner)
        }
        .onChange(of: phase) { _, new in
            if new == .background { runner.noteBackground() }
            if new == .active { runner.onForeground() }
        }
    }
}
