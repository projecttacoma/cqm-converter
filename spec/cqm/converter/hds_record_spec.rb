require 'spec_helper'

RSpec.describe CQM::Converter::HDSRecord do
  before(:all) do
    # Initialize a new HDS converter.
    @hds_record_converter = CQM::Converter::HDSRecord.new
  end

  it 'converts HDS EH 1 to QDM EH 1 properly' do
    hds_eh1 = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/1.json'))
    qdm_eh1 = @hds_record_converter.to_qdm(hds_eh1)
    expect(JSON.parse(qdm_eh1.to_json(except: [:_id]))).to eq(JSON.parse(File.read('spec/fixtures/qdm/records/eh/1.json')))
  end

  it 'converts HDS EH 2 to QDM EH 2 properly' do
    hds_eh2 = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/2.json'))
    qdm_eh2 = @hds_record_converter.to_qdm(hds_eh2)
    expect(JSON.parse(qdm_eh2.to_json(except: [:_id]))).to eq(JSON.parse(File.read('spec/fixtures/qdm/records/eh/2.json')))
  end

  it 'converts HDS EH 3 to QDM EH 3 properly' do
    hds_eh3 = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/3.json'))
    qdm_eh3 = @hds_record_converter.to_qdm(hds_eh3)
    expect(JSON.parse(qdm_eh3.to_json(except: [:_id]))).to eq(JSON.parse(File.read('spec/fixtures/qdm/records/eh/3.json')))
  end

  it 'converts HDS EP 1 to QDM EP 1 properly' do
    hds_ep1 = Record.new.from_json(File.read('spec/fixtures/hds/records/ep/1.json'))
    qdm_ep1 = @hds_record_converter.to_qdm(hds_ep1)
    expect(JSON.parse(qdm_ep1.to_json(except: [:_id]))).to eq(JSON.parse(File.read('spec/fixtures/qdm/records/ep/1.json')))
  end

  it 'converts HDS EP 2 to QDM EP 2 properly' do
    hds_ep2 = Record.new.from_json(File.read('spec/fixtures/hds/records/ep/2.json'))
    qdm_ep2 = @hds_record_converter.to_qdm(hds_ep2)
    expect(JSON.parse(qdm_ep2.to_json(except: [:_id]))).to eq(JSON.parse(File.read('spec/fixtures/qdm/records/ep/2.json')))
  end
end
