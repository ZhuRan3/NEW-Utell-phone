#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

fixture_path = ARGV.fetch(0, File.expand_path("../fixtures/diagnostic_redaction.json", __dir__))
fixture = JSON.parse(File.read(fixture_path))

abort "fixture_version must be 0.1" unless fixture.fetch("fixture_version") == "0.1"
abort "unexpected scenario key" unless fixture.fetch("scenario_key") == "diagnostic_redaction"
abort "fixture must not contain business data" unless fixture.fetch("contains_business_data") == false

# AC-017/7.3：导出物不得含私钥、Capture 原文、卡片标题/摘要、Pi 完整输出或可还原业务内容的数据。
forbidden_keys = %w[raw_text capture_text title summary pi_output private_key plaintext capture_id log_entry_id]
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

allowed_export_keys = fixture.fetch("allowed_export_keys")
abort "allowed_export_keys must be a non-empty array" unless allowed_export_keys.is_a?(Array) && !allowed_export_keys.empty?
abort "allowed_export_keys must not overlap forbidden fields" unless (allowed_export_keys & forbidden_keys).empty?

cases = fixture.fetch("cases")
abort "fixture must contain exactly four cases" unless cases.length == 4
expected_names = %w[export_requires_confirmation redacted_export error_history_export revoked_pairing_export]
abort "fixture must cover each export path exactly once" unless cases.map { |example| example.fetch("name") }.sort == expected_names.sort

cases.each do |example|
  name = example.fetch("name")

  # FR-007：导出前必须用户确认并完成脱敏；未确认不得产生导出物。
  abort "case #{name} must not produce export without confirmation" unless example.fetch("export_produced") == example.fetch("user_confirmed")

  export = example.fetch("export")
  if example.fetch("export_produced")
    abort "case #{name} must attach an export payload" unless export.is_a?(Hash)
    export.each_key do |key|
      abort "case #{name} export contains non-whitelisted key #{key}" unless allowed_export_keys.include?(key)
    end
  else
    abort "case #{name} must not attach an export payload" unless export.nil?
  end
end

puts "diagnostic_redaction_semantics=passed"
puts "cases=#{cases.length}"
puts "business_data=false"
