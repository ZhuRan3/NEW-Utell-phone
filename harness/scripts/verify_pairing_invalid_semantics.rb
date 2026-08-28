#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

fixture_path = ARGV.fetch(0, File.expand_path("../fixtures/pairing_invalid.json", __dir__))
fixture = JSON.parse(File.read(fixture_path))

abort "fixture_version must be 0.1" unless fixture.fetch("fixture_version") == "0.1"
abort "unexpected scenario key" unless fixture.fetch("scenario_key") == "pairing_invalid"
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
expected_names = %w[expired_token already_used_token fingerprint_mismatch device_revoked]
abort "fixture must cover each invalid pairing cause exactly once" unless cases.map { |example| example.fetch("name") }.sort == expected_names.sort

cases.each do |example|
  abort "pairing attempt must be present" unless example.fetch("pairing_attempted") == true
  invalid_conditions = [
    example.fetch("token_expired"),
    example.fetch("token_already_used"),
    !example.fetch("fingerprint_matches"),
    example.fetch("device_revoked")
  ].count(true)
  abort "case #{example.fetch('name')} must have exactly one invalid condition" unless invalid_conditions == 1
  abort "invalid pairing must map to PAIRING_INVALID" unless example.fetch("expected_error") == "PAIRING_INVALID"
  abort "invalid pairing must not be established" unless example.fetch("pairing_established") == false
  abort "invalid pairing must not start a session" unless example.fetch("session_established") == false
  abort "phone must remain UNPAIRED" unless example.fetch("expected_phone_state") == "UNPAIRED"
end

puts "pairing_invalid_semantics=passed"
puts "cases=#{cases.length}"
puts "business_data=false"
