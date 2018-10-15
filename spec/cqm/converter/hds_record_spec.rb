require 'spec_helper'

RSpec.describe CQM::Converter::HDSRecord do
  before(:all) do
    # Initialize a new HDS converter.
    @hds_record_converter = CQM::Converter::HDSRecord.new
  end

  it 'converts HDS to QDM and maintains id' do
    hds_eh_id_test = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/id_test.json'))
    qdm_eh_id_test = @hds_record_converter.to_qdm(hds_eh_id_test)

    # specifically check the id of the encounter is turned into a QDM.Id
    expect(qdm_eh_id_test.dataElements.first.id.value).to eq(hds_eh_id_test.encounters.first._id.to_s)

    qdm_eh_id_test_json = JSON.parse(to_utc(qdm_eh_id_test.to_json(except: '_id').to_s)).clean_hash
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/eh/id_test.json'))).clean_hash
    expect(qdm_eh_id_test_json).to eq(fixture)
  end

  it 'converts HDS to QDM and handles relatedTo' do
    # tests using an Assessment, Performed that is "relatedTo" an Encounter
    hds_eh_relatedto_test = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/relatedto_test.json'))

    # fix referenced_id to be a BSON::ObjectId
    encounter_ref_id = hds_eh_relatedto_test.assessments.first.references.first.referenced_id
    hds_eh_relatedto_test.assessments.first.references.first.referenced_id = BSON::ObjectId(encounter_ref_id)

    # convert the HDS document to QDM
    qdm_eh_relatedto_test = @hds_record_converter.to_qdm(hds_eh_relatedto_test)

    # grab the converted assessment element
    qdm_assessment = qdm_eh_relatedto_test.dataElements.select { |e| e.qdmCategory == 'assessment' }.first

    # specifically check the relatedTo in the assessment is the expected value
    expect(qdm_assessment.relatedTo.length).to eq(1)
    expect(qdm_assessment.relatedTo[0].value).to eq(encounter_ref_id)
  end

  it 'converts HDS EH 1 to QDM EH 1 properly' do
    hds_eh1 = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/1.json'))
    qdm_eh1 = @hds_record_converter.to_qdm(hds_eh1)
    # There are some 'id' fields that are an example of data loss between hds to
    # the qdm based on the model info file.  We test the 'id's that should persist above, so
    # can ignore them in these tests rather than updating them all.
    qdm_eh1_json = JSON.parse(to_utc(qdm_eh1.to_json(except: ['_id', 'id']).to_s)).clean_hash
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/eh/1.json')))
    fixture = JSON.parse(fixture.to_json(except: ['_id', 'id'])).clean_hash
    expect(qdm_eh1_json).to eq(fixture)
  end

  it 'converts HDS EH 2 to QDM EH 2 properly' do
    hds_eh2 = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/2.json'))
    qdm_eh2 = @hds_record_converter.to_qdm(hds_eh2)
    qdm_eh2_json = JSON.parse(to_utc(qdm_eh2.to_json(except: ['_id', 'id']).to_s)).clean_hash
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/eh/2.json'))).clean_hash
    fixture = JSON.parse(fixture.to_json(except: ['_id', 'id'])).clean_hash
    expect(qdm_eh2_json).to eq(fixture)
  end

  it 'converts HDS EH 3 to QDM EH 3 properly' do
    hds_eh3 = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/3.json'))
    qdm_eh3 = @hds_record_converter.to_qdm(hds_eh3)
    qdm_eh3_json = JSON.parse(to_utc(qdm_eh3.to_json(except: ['_id', 'id']).to_s)).clean_hash
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/eh/3.json'))).clean_hash
    fixture = JSON.parse(fixture.to_json(except: ['_id', 'id'])).clean_hash
    expect(qdm_eh3_json).to eq(fixture)
  end

  xit 'converts HDS EP 1 to QDM EP 1 properly' do
    hds_ep1 = Record.new.from_json(File.read('spec/fixtures/hds/records/ep/1.json'))
    qdm_ep1 = @hds_record_converter.to_qdm(hds_ep1)
    qdm_ep1_json = JSON.parse(to_utc(qdm_ep1.to_json(except: ['_id', 'id']).to_s)).clean_hash
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/ep/1.json'))).clean_hash
    fixture = JSON.parse(fixture.to_json(except: ['_id', 'id'])).clean_hash
    expect(qdm_ep1_json).to eq(fixture)
  end

  xit 'converts HDS EP 2 to QDM EP 2 properly' do
    hds_ep2 = Record.new.from_json(File.read('spec/fixtures/hds/records/ep/2.json'))
    qdm_ep2 = @hds_record_converter.to_qdm(hds_ep2)
    qdm_ep2_json = JSON.parse(to_utc(qdm_ep2.to_json(except: ['_id', 'id']).to_s)).clean_hash
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/ep/2.json'))).clean_hash
    fixture = JSON.parse(fixture.to_json(except: ['_id', 'id'])).clean_hash
    expect(qdm_ep2_json).to eq(fixture)
  end
end
