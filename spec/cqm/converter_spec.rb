require 'spec_helper'

RSpec.describe CQM::Converter do
  before(:all) do
    @converter_classes = CQM::Converter.constants.select do |c|
      CQM::Converter.const_get(c).is_a? Class
    end
    # Initialize a new HDS converter.
    @hds_record_converter = CQM::Converter::HDSRecord.new
    # Initialize a new QDM converter.
    @qdm_record_converter = CQM::Converter::QDMPatient.new
  end

  it 'QDMPatient class exists in the converter module' do
    expect(@converter_classes).to include(:QDMPatient)
  end

  it 'HDSRecord class exists in the converter module' do
    expect(@converter_classes).to include(:HDSRecord)
  end

  xit 'Successfully converts all HDS records to QDM records and back (roundtrip)' do
    Dir.glob('spec/fixtures/roundtrip/*.json').each do |record_path|
      # Read in fixture as an HDS Record.
      hds_record1 = Record.new.from_json(File.read(record_path))
      # Convert the HDS Record to a QDM Patient.
      cqm_record = @hds_record_converter.to_qdm(hds_record1)
      # Convert the QDM Patient back to an HDS Record.
      hds_record2 = @qdm_record_converter.to_hds(cqm_record)
      hds_record2_json = ignore_irrelavant_fields(JSON.parse(hds_record2.to_json(except: '_id', methods: :_type).to_s)).clean_hash
      fixture = ignore_irrelavant_fields(JSON.parse(File.read(record_path))).clean_hash
      # Make sure the HDS records are equivalent.
      puts '[ROUNDTRIP] checking: ' + record_path
      expect(hds_record2_json).to eq(fixture)
    end
  end
end
