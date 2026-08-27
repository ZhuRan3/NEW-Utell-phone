# SC-PH-2026-005 Projection 版本排序

日期：2026-08-25（Asia/Shanghai）
状态：Harness 语义检查通过；不代表公开契约 approved 或生产实现完成。

## 范围

- 验证手机在当前前台会话内首次接受当前 Projection。
- 验证重复版本和迟到的较低版本被丢弃，不覆盖当前内存视图。
- 验证更高 `event_version` 才能更新当前内存视图。
- 验证 Projection 不进入持久化存储；fixture 不包含业务正文或真实标识。

## 命令

```text
harness/scripts/verify_contract_gate.sh
ruby harness/scripts/verify_projection_version_ordering_semantics.rb harness/fixtures/projection_version_ordering.json
```

## 结果

```text
projection_version_ordering_semantics=passed
cases=4
business_data=false
```

## 负向结果

将迟到的 v7 篡改为 `expected_action=accept` 时，runner 拒绝该 fixture。

## 证据文件

- Fixture：`harness/fixtures/projection_version_ordering.json`
- Runner：`harness/scripts/verify_projection_version_ordering_semantics.rb`
- 场景登记：`harness/scenarios/catalog.yaml` / `SC-PH-2026-005`
