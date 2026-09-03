#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

fixture_path = ARGV.fetch(0, File.expand_path("../fixtures/session_memory_reset.json", __dir__))
fixture = JSON.parse(File.read(fixture_path))

abort "fixture_version must be 0.1" unless fixture.fetch("fixture_version") == "0.1"
abort "unexpected scenario key" unless fixture.fetch("scenario_key") == "session_memory_reset"
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
abort "fixture must contain exactly five cases" unless cases.length == 5
expected_names = %w[app_restart_clears_memory cold_start_without_cursor background_resume_resyncs exit_after_original_view killed_with_draft]
abort "fixture must cover each lifecycle event exactly once" unless cases.map { |example| example.fetch("name") }.sort == expected_names.sort

cases.each do |example|
  name = example.fetch("name")

  # 7.3/2.3：任何情况下不得读取持久化业务缓存；同步游标、原文、草稿均不得持久化（5.5、AC-029、AC-005）。
  abort "case #{name} must not read persistent business cache" unless example.fetch("persistent_business_cache_read") == false
  abort "case #{name} must not persist sync cursor" unless example.fetch("sync_cursor_persisted") == false
  abort "case #{name} must not retain original trace" unless example.fetch("original_trace_retained") == false
  abort "case #{name} must not auto-retry original trace" unless example.fetch("original_trace_auto_retry") == false
  abort "case #{name} must not persist draft" unless example.fetch("draft_persisted") == false
  abort "case #{name} must not recover draft" unless example.fetch("draft_recoverable") == false

  # 5.5：每次进入 READY（含后台恢复）均须发起一次 Projection 同步。
  abort "case #{name} must initiate projection resync" unless example.fetch("projection_resync_initiated") == true

  case example.fetch("event")
  when "app_restarted", "cold_start", "app_exit_after_original_trace", "app_killed_with_draft"
    # AC-010/AC-023/AC-029：退出、重启或被回收后清空内存视图，冷启动必须请求权威快照而非增量。
    abort "case #{name} must clear in-memory business view" unless example.fetch("memory_business_view_cleared") == true
    abort "case #{name} must request authority snapshot" unless example.fetch("authority_snapshot_requested") == true
    abort "case #{name} must not use incremental sync without cursor" unless example.fetch("incremental_sync_used") == false
  when "background_resumed_ready"
    # 5.5：当前 App 会话仍持有内存游标时允许增量同步。
    abort "case #{name} must keep session memory on resume" unless example.fetch("memory_business_view_cleared") == false
    abort "case #{name} must use in-memory cursor for incremental sync" unless example.fetch("incremental_sync_used") == true
  else
    abort "case #{name} has unknown event"
  end
end

puts "session_memory_reset_semantics=passed"
puts "cases=#{cases.length}"
puts "business_data=false"
