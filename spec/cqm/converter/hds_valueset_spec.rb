require 'spec_helper'

RSpec.describe CQM::Converter::HDSValueSet do
  it 'converts a list of valuesets' do
    bonnie_measure = CqlMeasure.new.from_json(File.read('spec/fixtures/bonnie/core_measures/CMS32v7.json'))
    hds_value_sets = JSON.parse(File.read('spec/fixtures/hds/valuesets/core_measures/CMS32v7.json')).map do |vs_json|
      HealthDataStandards::SVS::ValueSet.new(vs_json)
    end
    cqm_value_sets = CQM::Converter::HDSValueSet.list_to_cqm(hds_value_sets, bonnie_measure.value_set_oid_version_objects)
    expect(cqm_value_sets.size).to eq(bonnie_measure.value_set_oid_version_objects.size)
  end
end
