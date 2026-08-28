#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

fixture_path = ARGV.fetch(0, File.expand_path("../fixtures/card_command_version_conflict.json", __dir__))
fixture = JSON.parse(File.read(fixture_path))

abort "fixture_version must be 0.1" unless fixture.fetch("fixture_version") == "0.1"
abort "unexpected scenario key" unless fixture.fetch("scenario_key") == "card_command_version_conflict"
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
expected_names = %w[matching_expected_version stale_expected_version disconnect_before_command_receipt]
abort "fixture must cover each Card Command result case exactly once" unless cases.map { |example| example.fetch("name") }.sort == expected_names.sort

cases.each do |example|
  abort "Card Command must carry an event reference" unless example.fetch("command_event_reference_present") == true
  abort "expected_version must be a positive integer" unless example.fetch("expected_version").is_a?(Integer) && example.fetch("expected_version") >= 1
  abort "authoritative_version must be a positive integer" unless example.fetch("authoritative_version").is_a?(Integer) && example.fetch("authoritative_version") >= 1
  abort "Card Command must not be automatically resent" unless example.fetch("auto_resend") == false

  if example.fetch("transport_interrupted")
    abort "interrupted command must be unknown" unless example.fetch("expected_result") == "unknown"
    abort "interrupted command must not claim an error code" unless example.fetch("expected_error").nil?
    abort "interrupted command must not write authority" unless example.fetch("authority_write_performed") == false
    abort "recovery must refresh Projection" unless example.fetch("projection_refresh_required") == true
  elsif example.fetch("expected_version") == example.fetch("authoritative_version")
    abort "matching version must be accepted" unless example.fetch("expected_result") == "accepted"
    abort "matching version must not return VERSION_CONFLICT" unless example.fetch("expected_error").nil?
    abort "matching version must write authority" unless example.fetch("authority_write_performed") == true
  else
    abort "stale version must be rejected" unless example.fetch("expected_result") == "rejected"
    abort "stale version must map to VERSION_CONFLICT" unless example.fetch("expected_error") == "VERSION_CONFLICT"
    abort "VERSION_CONFLICT must not write authority" unless example.fetch("authority_write_performed") == false
    abort "VERSION_CONFLICT must refresh Projection" unless example.fetch("projection_refresh_required") == true
    abort "VERSION_CONFLICT must require user reconfirmation" unless example.fetch("user_reconfirmation_required") == true
  end
end

puts "card_command_version_conflict_semantics=passed"
puts "cases=#{cases.length}"
puts "business_data=false"
