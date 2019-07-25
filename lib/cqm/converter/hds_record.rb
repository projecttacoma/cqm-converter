require 'execjs'
require 'sprockets'
# CQM Converter module for HDS models.
module CQM::Converter
  # CQM Converter class for HDS based records.
  class HDSRecord
    # Initialize a new HDSRecord converter. NOTE: This should be done once, and then
    # used for every HDS Record you want to convert, since it takes a few seconds
    # to initialize the conversion environment using Sprockets.
    def initialize
      # Create a new sprockets environment.
      environment = Sprockets::Environment.new

      # Populate the JavaScript environment with the cql_qdm_patientapi mappings and
      # its dependencies.
      cql_qdm_patientapi_spec = Gem::Specification.find_by_name('cql_qdm_patientapi')
      momentjs_rails_spec = Gem::Specification.find_by_name('momentjs-rails')
      environment.append_path(cql_qdm_patientapi_spec.gem_dir + '/app/assets/javascripts')
      environment.append_path(cql_qdm_patientapi_spec.gem_dir + '/vendor/assets/javascripts')
      environment.append_path(momentjs_rails_spec.gem_dir + '/vendor/assets/javascripts')
      @js_dependencies = environment['moment'].to_s
      @js_dependencies += environment['cql4browsers'].to_s
      @js_dependencies += environment['cql_qdm_patientapi'].to_s
      @qdm_model_attrs = Utils.gather_qdm_model_attrs
    end

    # Given an HDS record, return a corresponding CQM patient that holds the QDM patient information.
    def to_cqm(record)
      # Start with a new CQM patient.
      patient = CQM::Patient.new
      patient.qdmPatient = to_qdm(record)

      patient.givenNames = record.first ? [record.first] : []
      patient.familyName = record.last if record.last
      patient.bundleId = record.bundle_id if record.bundle_id
      patient.expectedValues = record.expected_values if record.respond_to?('expected_values')
      patient.notes = record.notes if record.respond_to?('notes')

      measure_ids = []
      if record.respond_to?('measure_ids')
        record['measure_ids'].each do |measure_id|
          measure_ids << measure_id unless measure_id.nil?
        end
      end
      patient.measure_ids = measure_ids
      patient
    end

    # given an HDS data_criteria and HDS record, find code_list_id for coresponding data_criteria
    def find_code_list_id_for_element(data_criteria, record)
      code_list_id = nil
      source_data_criteria = record.source_data_criteria if record.respond_to?('source_data_criteria')
      if source_data_criteria
        data_criteria_source = source_data_criteria.select { |sdc| sdc['description'] == data_criteria['description'] }

        # Edge case where there are multiple source data criteria but they have different code_list_ids
        # Select the correct code_list_id based on the codes that are used
        if data_criteria_source.length > 1
          data_criteria_source.each do |sdc|
            data_criteria['dataElementCodes'].each do |code|
              if sdc['codes'].value?([code['code']])
                code_list_id = sdc['code_list_id']
              end
            end
          end
        end

        if data_criteria_source && code_list_id.nil?
          code_list_id = data_criteria_source[0]['code_list_id']
        end
      end

      code_list_id
    end

    def to_qdm(record)
      # Start with a new QDM patient.
      qdm_patient = QDM::Patient.new

      # Build and execute JavaScript that will create a 'CQL_QDM.Patient'
      # JavaScript version of the HDS record. Specifically, we will use
      # this to build our patient's 'dataElements'.
      cql_qdm_patient = ExecJS.exec Utils.hds_to_qdm_js(@js_dependencies, record, @qdm_model_attrs)

      # Make sure all date times are in the correct form.
      Utils.date_time_adjuster(cql_qdm_patient) if cql_qdm_patient

      # Grab the results from the CQL_QDM.Patient and add a new 'data_element'
      # for each datatype found on the CQL_QDM.Patient to the new QDM Patient.
      cql_qdm_patient.keys.each do |dc_type|
        cql_qdm_patient[dc_type].each do |dc|
          # Convert snake_case to camelCase
          dc_fixed_keys = dc.deep_transform_keys { |key| key.to_s.gsub(/^_/, '').camelize(:lower) }

          # Our Code model uses 'codeSystem' to describe the code system (since system is
          # a reserved keyword). The cql.Code calls this 'system', so make sure the proper
          # conversion is made. Also do this for 'display', where we call this descriptor.
          dc_fixed_keys = dc_fixed_keys.deep_transform_keys { |key| key.to_s == 'system' ? 'codeSystem' : key }
          dc_fixed_keys = dc_fixed_keys.deep_transform_keys { |key| key.to_s == 'display' ? 'descriptor' : key }

          # Remove the principalDiagnosis from the diagnoses field value. It gets duplicated
          # when pulling the data elements from the record
          if dc_type == 'EncounterPerformed' && dc_fixed_keys['principalDiagnosis'].present?
            principal_diagnosis_index = dc_fixed_keys['diagnoses'].index(dc_fixed_keys['principalDiagnosis'])
            dc_fixed_keys['diagnoses'].delete_at(principal_diagnosis_index)
          end

          data_element = generate_qdm_data_element(dc_fixed_keys, dc_type, record)
          qdm_patient.dataElements << data_element
        end
      end
      # Convert patient characteristic birthdate if one exists on the measure
      birthdate = record.birthdate
      measure = CQM::Measure.where(user_id: record.user_id, hqmf_set_id: record.measure_ids[0]).first if record.respond_to?('measure_ids')
      # Don't add birthdate if the patients are orphaned
      # Add birthdate characteristic if it is in the measure source data criteria
      if !measure.nil?
        birth_datetime = DateTime.strptime(birthdate.to_s, '%s')
        sdc = measure.source_data_criteria.select { |sdc| sdc.qdmTitle == 'Patient Characteristic Birthdate' }[0]
        concepts = nil
        if !sdc.nil?
          concepts = measure.value_sets.where({oid: sdc.codeListId })[0]&.concepts
          if !concepts.nil? && !concepts[0].nil? && !concepts[0].code.nil?
            code = concepts[0]
            qdm_patient.dataElements << QDM::PatientCharacteristicBirthdate.new(birthDatetime: birth_datetime, dataElementCodes: [code.code])
          end
        end

        # This case _shouldn't_ happen now that we are adding birthdate and expired onto measure source_data_criteria
        if concepts.nil?
          code = QDM::Code.new('21112-8', '2.16.840.1.113883.6.1', nil)
          qdm_patient.dataElements << QDM::PatientCharacteristicBirthdate.new(birthDatetime: birth_datetime, dataElementCodes: [code])
        end
      end

      # Convert patient characteristic clinical trial participant.
      # TODO, Adam 4/1: The Bonnie team is working on implementing this in HDS. When that work
      # is complete, this should be updated to reflect how that looks in HDS.
      # patient.dataElements << QDM::PatientCharacteristicClinicalTrialParticipant.new

      # Convert patient characteristic ethnicity.
      ethnicity = record.ethnicity
      if ethnicity
        # See: https://phinvads.cdc.gov/vads/ViewCodeSystem.action?id=2.16.840.1.113883.6.238
        # Bonnie currently uses 'CDC Race' instead of the correct 'CDC Race'.  This incorrect code is here as a temporary
        # workaround until the larger change of making bonnie use 'CDC Race' can be implemented.
        # Same change is present in `race` below.
        code = QDM::Code.new(ethnicity['code'], '2.16.840.1.113883.6.238', ethnicity['name'])
        qdm_patient.dataElements << QDM::PatientCharacteristicEthnicity.new(dataElementCodes: [code])
      end

      # Convert patient characteristic expired.
      expired = record.deathdate
      if !measure.nil? && !expired.nil?
        expired_datetime = DateTime.strptime(expired.to_s, '%s')
        sdc = (measure.source_data_criteria.select { |sdc| sdc.qdmTitle == 'Patient Characteristic Expired' })[0]
        concepts = nil
        if !sdc.nil?
          concepts = measure.value_sets.where({oid: sdc.codeListId })[0]&.concepts
          if !concepts.nil? && !concepts[0].nil? && !concepts[0].code.nil?
            code = concepts[0]
            qdm_patient.dataElements << QDM::PatientCharacteristicExpired.new(expiredDatetime: expired_datetime, dataElementCodes: [code.code])
          end
        end
        # This case _shouldn't_ happen now that we are adding birthdate and expired onto measure source_data_criteria
        if concepts.nil?
          code = QDM::Code.new('419099009', '2.16.840.1.113883.6.96')
          qdm_patient.dataElements << QDM::PatientCharacteristicExpired.new(expiredDatetime: expired_datetime, dataElementCodes: [code])
        end
      end

      # Convert patient characteristic race.
      race = record.race
      if race
        # See: https://phinvads.cdc.gov/vads/ViewCodeSystem.action?id=2.16.840.1.113883.6.238
        code = QDM::Code.new(race['code'], '2.16.840.1.113883.6.238', race['name'])
        # code = QDM::Code.new(race['code'], 'CDC Race', race['name'], '2.16.840.1.113883.6.238')
        qdm_patient.dataElements << QDM::PatientCharacteristicRace.new(dataElementCodes: [code])
      end

      # Convert patient characteristic sex.
      sex = record.gender
      if sex
        # See: https://phinvads.cdc.gov/vads/ViewCodeSystem.action?id=2.16.840.1.113883.5.1
        code = QDM::Code.new(sex, '2.16.840.1.113883.5.1', sex)
        qdm_patient.dataElements << QDM::PatientCharacteristicSex.new(dataElementCodes: [code])
      end

      # Convert remaining metadata.
      qdm_patient.birthDatetime = DateTime.strptime(record.birthdate.to_s, '%s') if record.birthdate
      # Convert extended_data.
      qdm_patient.extendedData = convert_extended_data(record)
      qdm_patient
    end

    def convert_extended_data(record)
      extended_data = {}
      extended_data['type'] = record.type if record.respond_to?('type')
      extended_data['is_shared'] = record.is_shared if record.respond_to?('is_shared')
      extended_data['origin_data'] = record.origin_data if record.respond_to?('origin_data')
      extended_data['test_id'] = record.test_id if record.respond_to?('test_id')
      extended_data['medical_record_number'] = record.medical_record_number if record.respond_to?('medical_record_number')
      extended_data['medical_record_assigner'] = record.medical_record_assigner if record.respond_to?('medical_record_assigner')
      extended_data['description'] = record.description if record.respond_to?('description')
      extended_data['description_category'] = record.description_category if record.respond_to?('description_category')
      extended_data['insurance_providers'] = record.insurance_providers.to_json(except: '_id') if record.respond_to?('insurance_providers')
      extended_data['provider_performances'] = record.provider_performances.to_json(except: '_id') unless record.provider_performances.empty?
      extended_data
    end

    def generate_qdm_data_element(dc_fixed_keys, dc_type, record)
      populate_codesystem_oid(dc_fixed_keys)
      data_element = QDM.const_get(dc_type).new(dc_fixed_keys)
      # Any nested QDM types that need initialization should be handled here
      # when converting from the QDM models to the HDS models.
      # For now, that should just be FacilityLocation objects and Id
      if data_element.is_a?(QDM::EncounterPerformed)
        data_element.facilityLocations = data_element.facilityLocations.map do |facility|
          QDM::FacilityLocation.new.from_json(facility.to_json)
        end
      end
      data_element.codeListId = find_code_list_id_for_element(dc_fixed_keys, record)
      data_element
    end

    # iterate over all of the fields
    # if array or one of the nested types (facility location) dive deeper
    # if object contains codeSystem and system doesn't have a value then set system to the correct OID
    def populate_codesystem_oid(entry)
      if entry.nil? || entry.is_a?(String) || entry.is_a?(BSON::ObjectId) ||
         entry.is_a?(Time) || entry.is_a?(Date) || entry.is_a?(Boolean) || entry.is_a?(Integer) || entry.is_a?(Float)
      elsif entry.is_a?(Array)
        entry.each { |elem| populate_codesystem_oid(elem) }
      elsif entry.is_a?(Hash)
        if entry['codeSystem'] || entry[:codeSystem]
          name_oid_hash = JSON.parse(File.read(File.join(File.dirname(__FILE__), 'name_oid_map.json')))
          if name_oid_hash[entry['codeSystem']].nil? && name_oid_hash[entry[:codeSystem]].nil?
            puts 'ERROR: Could Not Resolve OID For Code System ' + entry['codeSystem']
          else
            entry['system'] = name_oid_hash[entry['codeSystem']] || name_oid_hash[entry[:codeSystem]]
            # cqm codes mirror cql codes and do not include the human-readable codeSystem name
            entry.delete('codeSystem')
          end
        end
        if entry['descriptor'] || entry[:descriptor]
          entry['display'] = entry['descriptor'] || entry[:descriptor]
          entry.delete('descriptor')
        end
        entry.keys.each { |key| populate_codesystem_oid(entry[key]) }
      elsif entry.is_a?(QDM::DataElement) || entry.is_a?(QDM::Attribute)
        entry.attribute_names.each { |key| populate_codesystem_oid(entry[key]) }
      else
        puts 'WARNING: Unable To Search For Codes In ' + entry.to_s
      end
    end
  end
end
