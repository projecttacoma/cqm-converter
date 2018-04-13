require 'spec_helper'

RSpec.describe CQM::Converter::QDMPatient do
  before(:all) do
    # Initialize a new QDM converter.
    @qdm_record_converter = CQM::Converter::QDMPatient.new
  end

  it 'converts QDM EH 1 to HDS EH 1 properly' do
    qdm_eh1 = QDM::Patient.new.from_json(File.read('spec/fixtures/qdm/patients/eh/1.json'))
    hds_eh1 = @qdm_record_converter.to_hds(qdm_eh1)
    hds_eh1_json = ignore_irrelavant_fields(JSON.parse(hds_eh1.to_json(except: '_id', methods: :_type).to_s)).clean_hash
    fixture = ignore_irrelavant_fields(JSON.parse(File.read('spec/fixtures/hds/records/eh/1.json'))).clean_hash
    expect(hds_eh1_json.compact).to eq(fixture.compact)
  end

  it 'converts QDM EH 2 to HDS EH 2 properly' do
    qdm_eh2 = QDM::Patient.new.from_json(File.read('spec/fixtures/qdm/patients/eh/2.json'))
    hds_eh2 = @qdm_record_converter.to_hds(qdm_eh2)
    hds_eh2_json = ignore_irrelavant_fields(JSON.parse(hds_eh2.to_json(except: '_id', methods: :_type).to_s)).clean_hash
    fixture = ignore_irrelavant_fields(JSON.parse(File.read('spec/fixtures/hds/records/eh/2.json'))).clean_hash
    expect(hds_eh2_json.compact).to eq(fixture.compact)
  end

  it 'converts QDM EH 3 to HDS EH 3 properly' do
    qdm_eh3 = QDM::Patient.new.from_json(File.read('spec/fixtures/qdm/patients/eh/3.json'))
    hds_eh3 = @qdm_record_converter.to_hds(qdm_eh3)
    hds_eh3_json = ignore_irrelavant_fields(JSON.parse(hds_eh3.to_json(except: '_id', methods: :_type).to_s)).clean_hash
    fixture = ignore_irrelavant_fields(JSON.parse(File.read('spec/fixtures/hds/records/eh/3.json'))).clean_hash
    expect(hds_eh3_json.compact).to eq(fixture.compact)
  end

  it 'converts QDM EP 1 to HDS EP 1 properly' do
    qdm_ep1 = QDM::Patient.new.from_json(File.read('spec/fixtures/qdm/patients/ep/1.json'))
    hds_ep1 = @qdm_record_converter.to_hds(qdm_ep1)
    hds_ep1_json = ignore_irrelavant_fields(JSON.parse(hds_ep1.to_json(except: '_id', methods: :_type).to_s)).clean_hash
    fixture = ignore_irrelavant_fields(JSON.parse(File.read('spec/fixtures/hds/records/ep/1.json'))).clean_hash
    expect(hds_ep1_json.compact).to eq(fixture.compact)
  end

  it 'converts QDM EP 2 to HDS EP 2 properly' do
    qdm_ep2 = QDM::Patient.new.from_json(File.read('spec/fixtures/qdm/patients/ep/2.json'))
    hds_ep2 = @qdm_record_converter.to_hds(qdm_ep2)
    hds_ep2_json = ignore_irrelavant_fields(JSON.parse(hds_ep2.to_json(except: '_id', methods: :_type).to_s)).clean_hash
    fixture = ignore_irrelavant_fields(JSON.parse(File.read('spec/fixtures/hds/records/ep/2.json'))).clean_hash
    expect(hds_ep2_json.compact).to eq(fixture.compact)
  end
end
