#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

fixture_path = ARGV.fetch(0, File.expand_path("../fixtures/projection_version_ordering.json", __dir__))
fixture = JSON.parse(File.read(fixture_path))

abort "fixture_version must be 0.1" unless fixture.fetch("fixture_version") == "0.1"
abort "unexpected scenario key" unless fixture.fetch("scenario_key") == "projection_version_ordering"
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
abort "fixture must contain exactly four cases" unless cases.length == 4
expected_names = %w[initial_snapshot duplicate_version stale_lower_version newer_version]
abort "fixture must cover each projection ordering case exactly once" unless cases.map { |example| example.fetch("name") }.sort == expected_names.sort

cases.each do |example|
  current = example["current_event_version"]
  incoming = example.fetch("incoming_event_version")
  resulting = example.fetch("expected_memory_event_version")
  abort "incoming event_version must be a positive integer" unless incoming.is_a?(Integer) && incoming >= 1
  abort "current event_version must be nil or a positive integer" unless current.nil? || (current.is_a?(Integer) && current >= 1)
  abort "Projection must remain session-memory only" unless example.fetch("projection_persisted") == false

  if current.nil?
    abort "initial snapshot must be accepted" unless example.fetch("expected_action") == "accept"
    abort "initial snapshot must populate memory" unless example.fetch("memory_changed") == true
    abort "initial snapshot result must equal incoming version" unless resulting == incoming
  elsif incoming > current
    abort "higher version must be accepted" unless example.fetch("expected_action") == "accept"
    abort "higher version must update memory" unless example.fetch("memory_changed") == true
    abort "higher version result must equal incoming version" unless resulting == incoming
  else
    abort "duplicate or lower version must be discarded" unless example.fetch("expected_action") == "discard"
    abort "duplicate or lower version must not update memory" unless example.fetch("memory_changed") == false
    abort "discarded version must leave current memory unchanged" unless resulting == current
  end
end

puts "projection_version_ordering_semantics=passed"
puts "cases=#{cases.length}"
puts "business_data=false"
