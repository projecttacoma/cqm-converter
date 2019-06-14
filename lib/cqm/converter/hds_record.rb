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

          qdm_patient.dataElements << generate_qdm_data_element(dc_fixed_keys, dc_type)
        end
      end

      # Convert patient characteristic birthdate.
      birthdate = record.birthdate
      if birthdate
        birth_datetime = DateTime.strptime(birthdate.to_s, '%s')
        code = QDM::Code.new('21112-8', '2.16.840.1.113883.6.1', nil, 'LOINC')
        qdm_patient.dataElements << QDM::PatientCharacteristicBirthdate.new(birthDatetime: birth_datetime, dataElementCodes: [code])
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
        code = QDM::Code.new(ethnicity['code'], '2.16.840.1.113883.6.238', ethnicity['name'], 'CDC Race')
        # code = QDM::Code.new(ethnicity['code'], 'CDC Race', ethnicity['name'], '2.16.840.1.113883.6.238')
        qdm_patient.dataElements << QDM::PatientCharacteristicEthnicity.new(dataElementCodes: [code])
      end

      # Convert patient characteristic expired.
      expired = record.deathdate
      if expired
        expired_datetime = DateTime.strptime(expired.to_s, '%s')
        code = QDM::Code.new('419099009', '2.16.840.1.113883.6.96')
        qdm_patient.dataElements << QDM::PatientCharacteristicExpired.new(expiredDatetime: expired_datetime, dataElementCodes: [code])
      end

      # Convert patient characteristic race.
      race = record.race
      if race
        # See: https://phinvads.cdc.gov/vads/ViewCodeSystem.action?id=2.16.840.1.113883.6.238
        code = QDM::Code.new(race['code'], '2.16.840.1.113883.6.238', race['name'], 'CDC Race')
        # code = QDM::Code.new(race['code'], 'CDC Race', race['name'], '2.16.840.1.113883.6.238')
        qdm_patient.dataElements << QDM::PatientCharacteristicRace.new(dataElementCodes: [code])
      end

      # Convert patient characteristic sex.
      sex = record.gender
      if sex
        # See: https://phinvads.cdc.gov/vads/ViewCodeSystem.action?id=2.16.840.1.113883.5.1
        code = QDM::Code.new(sex, '2.16.840.1.113883.5.1', sex, 'AdministrativeGender')
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
      extended_data['source_data_criteria'] = record.source_data_criteria if record.respond_to?('source_data_criteria')
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

    def generate_qdm_data_element(dc_fixed_keys, dc_type)
      data_element = QDM.const_get(dc_type).new(dc_fixed_keys)
      # Any nested QDM types that need initialization should be handled here
      # when converting from the QDM models to the HDS models.
      # For now, that should just be FacilityLocation objects and Id
      if data_element.is_a?(QDM::EncounterPerformed)
        data_element.facilityLocations = data_element.facilityLocations.map do |facility|
          QDM::FacilityLocation.new.from_json(facility.to_json)
        end
      end
      populate_codesystem_oid(data_element)
      # iterate over all of the fields
      # if array or one of the nested types (facility location) dive deeper
      # if object contains codeSystem and codeSystemOid doesn't have a value then set codeSystemOid to the correct OID
      data_element
    end

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
            entry['codeSystemOid'] = name_oid_hash[entry['codeSystem']] || name_oid_hash[entry[:codeSystem]]
          end
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
