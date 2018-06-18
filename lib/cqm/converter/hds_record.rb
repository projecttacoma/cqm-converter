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

    # Given an HDS record, return a corresponding QDM patient.
    def to_qdm(record)
      # Start with a new QDM patient.
      patient = QDM::Patient.new

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
          dc_fixed_keys = dc_fixed_keys.deep_transform_keys { |key| key.to_s == 'system' ? :codeSystem : key }
          dc_fixed_keys = dc_fixed_keys.deep_transform_keys { |key| key.to_s == 'display' ? :descriptor : key }

          patient.dataElements << generate_qdm_data_element(dc_fixed_keys, dc_type)
        end
      end

      # Convert patient characteristic birthdate.
      birthdate = record.birthdate
      if birthdate
        birth_datetime = DateTime.strptime(birthdate.to_s, '%s')
        code = QDM::Code.new('21112-8', 'LOINC')
        patient.dataElements << QDM::PatientCharacteristicBirthdate.new(birthDatetime: birth_datetime, dataElementCodes: [code])
      end

      # Convert patient characteristic clinical trial participant.
      # TODO, Adam 4/1: The Bonnie team is working on implementing this in HDS. When that work
      # is complete, this should be updated to reflect how that looks in HDS.
      # patient.dataElements << QDM::PatientCharacteristicClinicalTrialParticipant.new

      # Convert patient characteristic ethnicity.
      ethnicity = record.ethnicity
      if ethnicity
        # See: https://phinvads.cdc.gov/vads/ViewCodeSystem.action?id=2.16.840.1.113883.6.238
        code = QDM::Code.new(ethnicity['code'], 'cdcrec', ethnicity['name'], '2.16.840.1.113883.6.238')
        patient.dataElements << QDM::PatientCharacteristicEthnicity.new(dataElementCodes: [code])
      end

      # Convert patient characteristic expired.
      expired = record.deathdate
      if expired
        expired_datetime = DateTime.strptime(expired.to_s, '%s')
        code = QDM::Code.new('419099009', 'SNOMED-CT')
        patient.dataElements << QDM::PatientCharacteristicExpired.new(expiredDatetime: expired_datetime, dataElementCodes: [code])
      end

      # Convert patient characteristic race.
      race = record.race
      if race
        # See: https://phinvads.cdc.gov/vads/ViewCodeSystem.action?id=2.16.840.1.113883.6.238
        code = QDM::Code.new(race['code'], 'cdcrec', race['name'], '2.16.840.1.113883.6.238')
        patient.dataElements << QDM::PatientCharacteristicRace.new(dataElementCodes: [code])
      end

      # Convert patient characteristic sex.
      sex = record.gender
      if sex
        # See: https://phinvads.cdc.gov/vads/ViewCodeSystem.action?id=2.16.840.1.113883.5.1
        code = QDM::Code.new(sex, 'AdministrativeGender', sex, '2.16.840.1.113883.5.1')
        patient.dataElements << QDM::PatientCharacteristicSex.new(dataElementCodes: [code])
      end

      # Convert remaining metadata.
      patient.birthDatetime = DateTime.strptime(record.birthdate.to_s, '%s') if record.birthdate
      patient.givenNames = record.first ? [record.first] : []
      patient.familyName = record.last if record.last
      patient.bundleId = record.bundle_id if record.bundle_id

      # Convert extended_data.
      patient.extendedData = {}
      patient.extendedData['type'] = record.type if record.respond_to?('type')
      patient.extendedData['measure_ids'] = record.measure_ids if record.respond_to?('measure_ids')
      patient.extendedData['source_data_criteria'] = record.source_data_criteria if record.respond_to?('source_data_criteria')
      patient.extendedData['expected_values'] = record.expected_values if record.respond_to?('expected_values')
      patient.extendedData['notes'] = record.notes if record.respond_to?('notes')
      patient.extendedData['is_shared'] = record.is_shared if record.respond_to?('is_shared')
      patient.extendedData['origin_data'] = record.origin_data if record.respond_to?('origin_data')
      patient.extendedData['test_id'] = record.test_id if record.respond_to?('test_id')
      patient.extendedData['medical_record_number'] = record.medical_record_number if record.respond_to?('medical_record_number')
      patient.extendedData['medical_record_assigner'] = record.medical_record_assigner if record.respond_to?('medical_record_assigner')
      patient.extendedData['description'] = record.description if record.respond_to?('description')
      patient.extendedData['description_category'] = record.description_category if record.respond_to?('description_category')
      patient.extendedData['insurance_providers'] = record.insurance_providers.to_json(except: '_id') if record.respond_to?('insurance_providers')
      patient.extendedData['provider_performances'] = record.provider_performances.to_json(except: '_id') unless record.provider_performances.empty?

      patient
    end

    def generate_qdm_data_element(dc_fixed_keys, dc_type)
      data_element = QDM.const_get(dc_type).new.from_json(dc_fixed_keys.to_json)

      # Any nested QDM types that need initialization should be handled here
      # when converting from the QDM models to the HDS models.
      # For now, that should just be FacilityLocation objects
      if data_element.is_a?(QDM::EncounterPerformed)
        data_element.facilityLocations = data_element.facilityLocations.map do |facility|
          QDM::FacilityLocation.new.from_json(facility.to_json)
        end
      end

      data_element
    end
  end
end
