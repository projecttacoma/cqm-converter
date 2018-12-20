require 'spec_helper'

RSpec.describe CQM::Converter::HDSValueSet do
  it 'converts a list of valuesets' do
    hds_value_sets = JSON.parse(File.read('spec/fixtures/hds/valuesets/core_measures/CMS32v7.json')).map do |vs_json|
      HealthDataStandards::SVS::ValueSet.new(vs_json)
    end

    cqm_value_sets = CQM::Converter::HDSValueSet.list_to_cqm(hds_value_sets)

    expect(cqm_value_sets.size).to eq(hds_value_sets.size)
  end
end
