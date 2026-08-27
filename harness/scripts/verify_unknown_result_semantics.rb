#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

fixture_path = ARGV.fetch(0, File.expand_path("../fixtures/unknown_result.json", __dir__))
fixture = JSON.parse(File.read(fixture_path))

abort "fixture_version must be 0.1" unless fixture.fetch("fixture_version") == "0.1"
abort "unexpected scenario key" unless fixture.fetch("scenario_key") == "unknown_result"
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
abort "fixture must contain exactly two cases" unless cases.length == 2

cases.each do |example|
  abort "capture must have been sent" unless example.fetch("capture_sent") == true
  abort "persistent receipt must be absent" unless example.fetch("persistent_receipt_observed") == false
  abort "transport interruption must be present" unless example.fetch("transport_interrupted") == true
  abort "automatic resend is forbidden" unless example.fetch("auto_resend") == false
  abort "business payload persistence is forbidden" unless example.fetch("business_payload_persisted") == false

  if example.fetch("app_session_active")
    abort "active-session case must show UNKNOWN_RESULT" unless example.fetch("expected_phone_state") == "UNKNOWN_RESULT"
    abort "active-session lookup must be allowed after READY" unless example.fetch("current_session_lookup_allowed_after_ready") == true
  else
    abort "ended-session case must not restore business payload" unless example.fetch("business_payload_restored") == false
    abort "ended-session case must not restore submission task" unless example.fetch("submission_task_restored") == false
    abort "ended-session lookup must not be allowed" unless example.fetch("current_session_lookup_allowed_after_ready") == false
  end
end

puts "unknown_result_semantics=passed"
puts "cases=#{cases.length}"
puts "business_data=false"
