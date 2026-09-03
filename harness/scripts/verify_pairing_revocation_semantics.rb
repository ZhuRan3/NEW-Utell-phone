#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

fixture_path = ARGV.fetch(0, File.expand_path("../fixtures/pairing_revocation.json", __dir__))
fixture = JSON.parse(File.read(fixture_path))

abort "fixture_version must be 0.1" unless fixture.fetch("fixture_version") == "0.1"
abort "unexpected scenario key" unless fixture.fetch("scenario_key") == "pairing_revocation"
abort "fixture must not contain business data" unless fixture.fetch("contains_business_data") == false

forbidden_keys = %w[raw_text capture_text title summary capture_id log_entry_id private_key plaintext]
walk = lambda do |value|
  case value
  when Hash
    value.each do |key, child|
      abort "fixture contains forbidden field #{key}" if forbidden_keys.include?(key)
      walk.call(child)
    end
  when Array
    value.each { |child| walk.call(child) }
  end
end
walk.call(fixture)

cases = fixture.fetch("cases")
abort "fixture must contain exactly three cases" unless cases.length == 3
expected_names = %w[revoke_confirmed revoked_device_reconnect revoke_failure_keeps_state]
abort "fixture must cover each revocation path exactly once" unless cases.map { |example| example.fetch("name") }.sort == expected_names.sort

cases.each do |example|
  name = example.fetch("name")

  # AC-018：撤销后 Connector 不删除权威历史数据（所有路径均成立）。
  abort "case #{name} must retain authority history" unless example.fetch("authority_history_retained") == true

  # 5.2：UNPAIRED 时禁用输入并展示配对入口。
  if example.fetch("expected_phone_state") == "UNPAIRED"
    abort "case #{name} must disable input while UNPAIRED" unless example.fetch("input_enabled") == false
    abort "case #{name} must show pairing entry while UNPAIRED" unless example.fetch("pairing_entry_shown") == true
  end

  # 已撤销 pairing 不得再有会话，Relay 必须拒绝后续路由（AC-018）。
  if example.fetch("pairing_remains_active") == false
    abort "case #{name} must not keep a session after revocation" unless example.fetch("session_established") == false
    abort "case #{name} must reject further routing after revocation" unless example.fetch("relay_rejects_further_routing") == true
  end

  case name
  when "revoke_confirmed"
    # AC-018：用户撤销且 Connector 确认后，手机进入 UNPAIRED。
    abort "confirmed revocation requires user request" unless example.fetch("user_revoke_requested") == true
    abort "confirmed revocation requires connector acknowledgement" unless example.fetch("connector_acknowledged") == true
    abort "confirmed revocation must end pairing" unless example.fetch("pairing_remains_active") == false
    abort "confirmed revocation must move phone to UNPAIRED" unless example.fetch("expected_phone_state") == "UNPAIRED"
  when "revoked_device_reconnect"
    # AC-002：已撤销设备重新认证/建连必须拒绝并映射为 PAIRING_INVALID。
    abort "revoked device reconnect must be rejected as PAIRING_INVALID" unless example.fetch("expected_error") == "PAIRING_INVALID"
    abort "revoked device must not establish a session" unless example.fetch("session_established") == false
  when "revoke_failure_keeps_state"
    # FR-007 异常：撤销失败时保留原状态并提示重试。
    abort "failed revocation requires a prior user request" unless example.fetch("user_revoke_requested") == true
    abort "failed revocation must keep pairing active" unless example.fetch("pairing_remains_active") == true
    abort "failed revocation must show retry prompt" unless example.fetch("retry_prompt_shown") == true
    abort "failed revocation must keep phone state unchanged" unless example.fetch("expected_phone_state") == "READY"
  end
end

puts "pairing_revocation_semantics=passed"
puts "cases=#{cases.length}"
puts "business_data=false"
