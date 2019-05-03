require 'spec_helper'

RSpec.describe CQM::Converter::HDSRecord do
  before(:all) do
    # Initialize a new HDS converter.
    @hds_record_converter = CQM::Converter::HDSRecord.new
  end

  it 'converts HDS to QDM and maintains id' do
    hds_eh_id_test = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/id_test.json'))
    cqm_eh_id_test = @hds_record_converter.to_cqm(hds_eh_id_test)

    # specifically check the id of the encounter is turned into a QDM.Id
    expect(cqm_eh_id_test.qdmPatient.dataElements.first.id.value).to eq(hds_eh_id_test.encounters.first._id.to_s)
    cqm_eh_id_test_json = JSON.parse(to_utc(cqm_eh_id_test.qdmPatient.to_json(except: '_id').to_s)).clean_hash
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/eh/id_test.json'))).clean_hash
    expect(cqm_eh_id_test_json).to eq(fixture)
  end

  it 'converts HDS to QDM and handles relatedTo' do
    # tests using an Assessment, Performed that is "relatedTo" an Encounter
    hds_eh_relatedto_test = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/relatedto_test.json'))

    # fix referenced_id to be a BSON::ObjectId
    encounter_ref_id = hds_eh_relatedto_test.assessments.first.references.first.referenced_id
    hds_eh_relatedto_test.assessments.first.references.first.referenced_id = BSON::ObjectId(encounter_ref_id)

    # convert the HDS document to QDM
    cqm_eh_relatedto_test = @hds_record_converter.to_cqm(hds_eh_relatedto_test)

    # grab the converted assessment element
    qdm_assessment = cqm_eh_relatedto_test.qdmPatient.dataElements.select { |e| e.qdmCategory == 'assessment' }.first

    # specifically check the relatedTo in the assessment is the expected value
    expect(qdm_assessment.relatedTo.length).to eq(1)
    expect(qdm_assessment.relatedTo[0].value).to eq(encounter_ref_id)
  end

  it 'converts HDS EH 1 to QDM EH 1 properly' do
    hds_eh1 = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/1.json'))
    cqm_eh1 = @hds_record_converter.to_cqm(hds_eh1)
    # There are some 'id' fields that are an example of data loss between hds to
    # the qdm based on the model info file.  We test the 'id's that should persist above, so
    # can ignore them in these tests rather than updating them all.
    qdm_eh1_json = JSON.parse(to_utc(cqm_eh1.qdmPatient.to_json(except: ['_id', 'id']).to_s)).clean_hash
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/eh/1.json')))
    fixture = JSON.parse(fixture.to_json(except: ['_id', 'id'])).clean_hash
    fixture = fixture['qdmPatient']
    expect(qdm_eh1_json).to eq(fixture)
  end

  it 'converts HDS EH 2 to QDM EH 2 properly' do
    hds_eh2 = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/2.json'))
    cqm_eh2 = @hds_record_converter.to_cqm(hds_eh2)
    qdm_eh2_json = JSON.parse(to_utc(cqm_eh2.qdmPatient.to_json(except: ['_id', 'id']).to_s)).clean_hash
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/eh/2.json'))).clean_hash
    fixture = JSON.parse(fixture.to_json(except: ['_id', 'id'])).clean_hash
    fixture = fixture['qdmPatient']

    expect(qdm_eh2_json['birthDatetime']).to eq(fixture['birthDatetime'])
    expect(qdm_eh2_json['qdmVersion']).to eq(fixture['qdmVersion'])

    hds_data_elements = qdm_eh2_json['dataElements']
    qdm_data_elements = fixture['dataElements']
    expect(hds_data_elements.count).to eq(qdm_data_elements.count)

    hds_element = hds_data_elements.select { |e| e['_type'] == 'QDM::PatientCharacteristicBirthdate' }
    qdm_element = qdm_data_elements.select { |e| e['_type'] == 'QDM::PatientCharacteristicBirthdate' }
    expect(hds_element).to eq(qdm_element)
    hds_element = hds_data_elements.select { |e| e['_type'] == 'QDM::LaboratoryTestPerformed' }
    qdm_element = qdm_data_elements.select { |e| e['_type'] == 'QDM::LaboratoryTestPerformed' }
    expect(hds_element).to eq(qdm_element)
    hds_element = hds_data_elements.select { |e| e['_type'] == 'QDM::PatientCharacteristicSex' }
    qdm_element = qdm_data_elements.select { |e| e['_type'] == 'QDM::PatientCharacteristicSex' }
    expect(hds_element).to eq(qdm_element)
    hds_element = hds_data_elements.select { |e| e['_type'] == 'QDM::PatientCharacteristicEthnicity' }
    qdm_element = qdm_data_elements.select { |e| e['_type'] == 'QDM::PatientCharacteristicEthnicity' }
    expect(hds_element).to eq(qdm_element)
    hds_element = hds_data_elements.select { |e| e['_type'] == 'QDM::PatientCharacteristicRace' }
    qdm_element = qdm_data_elements.select { |e| e['_type'] == 'QDM::PatientCharacteristicRace' }
    expect(hds_element).to eq(qdm_element)
    hds_element = hds_data_elements.select { |e| e['_type'] == 'QDM::EncounterPerformed' }
    qdm_element = qdm_data_elements.select { |e| e['_type'] == 'QDM::EncounterPerformed' }
    expect(hds_element.count).to eq(qdm_element.count)
    hds_element = hds_data_elements.select { |e| e['_type'] == 'QDM::EncounterOrder' }
    qdm_element = qdm_data_elements.select { |e| e['_type'] == 'QDM::EncounterOrder' }
    expect(hds_element).to eq(qdm_element)
    hds_element = hds_data_elements.select { |e| e['_type'] == 'QDM::Diagnosis' }
    qdm_element = qdm_data_elements.select { |e| e['_type'] == 'QDM::Diagnosis' }
    expect(hds_element).to eq(qdm_element)

    expect(qdm_eh2_json['extendedData'].count).to eq(fixture['extendedData'].count)
    expect(qdm_eh2_json['extendedData']).to eq(fixture['extendedData'])
  end

  it 'converts HDS EH 3 to QDM EH 3 properly' do
    hds_eh3 = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/3.json'))
    cqm_eh3 = @hds_record_converter.to_cqm(hds_eh3)
    qdm_eh3_json = JSON.parse(to_utc(cqm_eh3.qdmPatient.to_json(except: ['_id', 'id']).to_s)).clean_hash
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/eh/3.json'))).clean_hash
    fixture = JSON.parse(fixture.to_json(except: ['_id', 'id'])).clean_hash
    fixture = fixture['qdmPatient']
    expect(qdm_eh3_json).to eq(fixture)
  end

  xit 'converts HDS EP 1 to QDM EP 1 properly' do
    hds_ep1 = Record.new.from_json(File.read('spec/fixtures/hds/records/ep/1.json'))
    cqm_ep1 = @hds_record_converter.to_cqm(hds_ep1)
    qdm_ep1_json = JSON.parse(to_utc(cqm_ep1.qdmPatient.to_json(except: ['_id', 'id']).to_s)).clean_hash
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/ep/1.json'))).clean_hash
    fixture = JSON.parse(fixture.to_json(except: ['_id', 'id'])).clean_hash
    expect(qdm_ep1_json).to eq(fixture)
  end

  xit 'converts HDS EP 2 to QDM EP 2 properly' do
    hds_ep2 = Record.new.from_json(File.read('spec/fixtures/hds/records/ep/2.json'))
    cqm_ep2 = @hds_record_converter.to_cqm(hds_ep2)
    qdm_ep2_json = JSON.parse(to_utc(cqm_ep2.qdmPatient.to_json(except: ['_id', 'id']).to_s)).clean_hash
    fixture = JSON.parse(to_utc(File.read('spec/fixtures/qdm/patients/ep/2.json'))).clean_hash
    fixture = JSON.parse(fixture.to_json(except: ['_id', 'id'])).clean_hash
    expect(qdm_ep2_json).to eq(fixture)
  end
end
