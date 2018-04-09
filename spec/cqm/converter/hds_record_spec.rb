require 'spec_helper'

RSpec.describe CQM::Converter::HDSRecord do
  before(:all) do
    # Initialize a new HDS converter.
    @hds_record_converter = CQM::Converter::HDSRecord.new
  end

  it 'converts HDS EH 1 to QDM EH 1 properly' do
    hds_eh1 = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/1.json'))
    qdm_eh1 = @hds_record_converter.to_qdm(hds_eh1)
    qdm_eh1_json = JSON.parse(to_utc(qdm_eh1.to_json(except: '_id').to_s))
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/eh/1.json')))
    expect(qdm_eh1_json).to eq(fixture)
  end

  it 'converts HDS EH 2 to QDM EH 2 properly' do
    hds_eh2 = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/2.json'))
    qdm_eh2 = @hds_record_converter.to_qdm(hds_eh2)
    qdm_eh2_json = JSON.parse(to_utc(qdm_eh2.to_json(except: '_id').to_s))
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/eh/2.json')))
    expect(qdm_eh2_json).to eq(fixture)
  end

  it 'converts HDS EH 3 to QDM EH 3 properly' do
    hds_eh3 = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/3.json'))
    qdm_eh3 = @hds_record_converter.to_qdm(hds_eh3)
    qdm_eh3_json = JSON.parse(to_utc(qdm_eh3.to_json(except: '_id').to_s))
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/eh/3.json')))
    expect(qdm_eh3_json).to eq(fixture)
  end

  it 'converts HDS EP 1 to QDM EP 1 properly' do
    hds_ep1 = Record.new.from_json(File.read('spec/fixtures/hds/records/ep/1.json'))
    qdm_ep1 = @hds_record_converter.to_qdm(hds_ep1)
    qdm_ep1_json = JSON.parse(to_utc(qdm_ep1.to_json(except: '_id').to_s))
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/ep/1.json')))
    expect(qdm_ep1_json).to eq(fixture)
  end

  it 'converts HDS EP 2 to QDM EP 2 properly' do
    hds_ep2 = Record.new.from_json(File.read('spec/fixtures/hds/records/ep/2.json'))
    qdm_ep2 = @hds_record_converter.to_qdm(hds_ep2)
    qdm_ep2_json = JSON.parse(to_utc(qdm_ep2.to_json(except: '_id').to_s))
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/ep/2.json')))
    expect(qdm_ep2_json).to eq(fixture)
  end

  # Forces serialized models to use UTC for date and times. This is used for comparing date
  # and times between JSON versions of records (i.e. useful for testing ONLY).
  def to_utc(contents)
    date_time_pattern = /\d{4}-[01]\d-[0-3]\dT[0-2]\d:[0-5]\d:[0-5]\d\.\d+([+-][0-2]\d:[0-5]\d|Z)/
    contents.gsub(date_time_pattern) do |match|
      DateTime.parse(match).new_offset(0).to_s
    end
  end
end
