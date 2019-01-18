require_relative './simplecov_init'
require 'bundler/setup'
require 'cqm/converter'
require 'json'

class User
  include Mongoid::Document
end

Mongoid.load!('config/mongoid.yml', :test)
Mongo::Logger.logger.level = Logger::FATAL

RSpec.configure do |config|
  # Disable RSpec exposing methods globally on `Module` and `main`.
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def dump_database
  Mongoid.client(:default).database.drop
end

# Forces serialized models to use UTC for date and times. This is used for comparing date
# and times between JSON versions of records (i.e. useful for testing ONLY).
def to_utc(contents)
  date_time_pattern = /\d{4}-[01]\d-[0-3]\dT[0-2]\d:[0-5]\d:[0-5]\d\.\d+([+-][0-2]\d:[0-5]\d|Z)/
  contents.gsub(date_time_pattern) do |match|
    DateTime.parse(match).new_offset(0).to_s
  end
end

# Helper method to strip fields we don't care about comparing.
def ignore_irrelavant_fields(json)
  ignore = ['created_at', 'updated_at', 'bundle_id', 'status_code']
  # Unused Encounter fields (start_time and end_time are used instead).
  ignore += ['admitTime', 'dischargeTime', 'transferFrom']
  # Unnecessary Bonnie stuff (measure history, patient bank, expired).
  ignore += ['calc_results', 'has_measure_history', 'results_exceed_storage', 'results_size', 'version', 'is_shared', 'expired', 'expected_values']
  # Unused Medication fields.
  ignore += ['fulfillmentHistory', 'administrationTiming', 'allowedAdministrations']
  # Codes will now correctly include all codes instead of just one
  ignore += ['codes']
  # TODO: Uncomment this once 'related-to' has been added to cqm-models
  ignore += ['references']
  ignore.each { |ignore_key| json.deep_reject_key!(ignore_key) }
  json
end

# Extension to Hash to deep delete the given key (recusive on any nested Hashes and
# Arrays that might be in the has that deep_reject_key! is called on).
class Hash
  def deep_reject_key!(key)
    keys.each { |k| delete(k) if k == key || self[k] == self[key] }
    values.each { |v| v.deep_reject_key!(key) if v.is_a? Hash }
    values.each do |v|
      next unless v.is_a? Array

      v.each do |el|
        el.deep_reject_key!(key) if el.is_a? Hash
      end
    end
    self
  end
end

# Extension to Hash to deep clean hashes for test comparison purposes. This makes sure
# things are always in order, specifically for some tricky cases with data elements.
#
# This makes: {a: 'b', c: 'd'} == {c: 'd', a: 'b'}
class Hash
  def clean_hash(&block)
    self.class[
      each do |k, v|
        self[k] = v.clean_hash(&block) if v.is_a? Hash
        next unless v.is_a? Array

        self[k] = v.collect { |a| a.clean_hash(&block) if a.is_a? Hash }
        if self[k].first&.stringify_keys&.key?('description')
          self[k] = self[k].sort_by { |h| h['description'] || '' }
        end
      end.sort(&block)
    ]
  end
end
