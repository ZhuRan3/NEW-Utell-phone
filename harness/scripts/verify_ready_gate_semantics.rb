#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

fixture_path = ARGV.fetch(0, File.expand_path("../fixtures/ready_gate.json", __dir__))
fixture = JSON.parse(File.read(fixture_path))

abort "fixture_version must be 0.1" unless fixture.fetch("fixture_version") == "0.1"
abort "unexpected scenario key" unless fixture.fetch("scenario_key") == "ready_gate"
abort "fixture must not contain business data" unless fixture.fetch("contains_business_data") == false
max_age = fixture.fetch("health_max_age_seconds")
abort "health max age must be 30 seconds" unless max_age == 30

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
abort "fixture must contain exactly six cases" unless cases.length == 6
expected_states = {
  "all_ready_conditions" => "READY",
  "relay_unreachable" => "NOT_READY_RELAY",
  "connector_offline" => "NOT_READY_CONNECTOR",
  "connector_incompatible" => "NOT_READY_CONNECTOR",
  "authority_storage_unavailable" => "NOT_READY_STORAGE",
  "health_stale" => "UNKNOWN"
}
abort "fixture must cover each ready gate case exactly once" unless cases.map { |example| example.fetch("name") }.sort == expected_states.keys.sort

cases.each do |example|
  conditions = [
    example.fetch("relay_connected"),
    example.fetch("connector_online"),
    example.fetch("capability_compatible"),
    example.fetch("authority_storage_accepting"),
    example.fetch("health_age_seconds") <= max_age
  ]
  expected_state = example.fetch("expected_phone_state")
  if expected_state == "READY"
    abort "READY case must satisfy every gate" unless conditions.all?
    abort "READY case must enable input" unless example.fetch("input_enabled") == true
  else
    abort "non-READY case must fail exactly one gate" unless conditions.count(false) == 1
    abort "non-READY case must disable input" unless example.fetch("input_enabled") == false
  end
  abort "case #{example.fetch('name')} has unexpected state" unless expected_states.fetch(example.fetch("name")) == expected_state
end

puts "ready_gate_semantics=passed"
puts "cases=#{cases.length}"
puts "business_data=false"
