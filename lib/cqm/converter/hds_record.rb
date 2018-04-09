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
      @datatype_attributes = Utils.gather_qdm_model_attrs
    end

    # Given an HDS record, return a corresponding QDM patient.
    def to_qdm(record)
      # Start with a new QDM patient.
      patient = QDM::Patient.new

      # Build and execute JavaScript that will create a 'CQL_QDM.Patient'
      # JavaScript version of the HDS record. Specifically, we will use
      # this to build our patient's 'data_elements'.
      cql_qdm_patient = ExecJS.exec Utils.hds_to_qdm_js(@js_dependencies, record, @datatype_attributes)

      # Grab the results from the CQL_QDM.Patient and add a new 'data_element'
      # for each datatype found on the CQL_QDM.Patient to the new QDM Patient.
      cql_qdm_patient.keys.each do |dc_type|
        cql_qdm_patient[dc_type].each do |dc|
          # Convert mixedCase to underscore_case
          dc_fixed_keys = dc.deep_transform_keys { |key| key.to_s.underscore }

          # Our Code model uses 'code_system' to describe the code system (since system is
          # a reserved keyword). The cql.Code calls this 'system', so make sure the proper
          # conversion is made.
          dc_fixed_keys = dc_fixed_keys.deep_transform_keys { |key| key.to_s == 'system' ? :code_system : key }

          patient.data_elements << QDM.const_get(dc_type).new.from_json(dc_fixed_keys.to_json)
        end
      end

      # Convert patient characteristic birthdate.
      birthdate = record.birthdate
      if birthdate
        birth_datetime = DateTime.strptime(birthdate.to_s, '%s')
        patient.data_elements << QDM::PatientCharacteristicBirthdate.new(birth_datetime: birth_datetime)
      end

      # Convert patient characteristic clinical trial participant.
      # TODO, Adam 4/1: The Bonnie team is working on implementing this in HDS. When that work
      # is complete, this should be updated to reflect how that looks in HDS.
      # patient.data_elements << QDM::PatientCharacteristicClinicalTrialParticipant.new

      # Convert patient characteristic ethnicity.
      ethnicity = record.ethnicity
      if ethnicity
        code = QDM::Code.new(ethnicity['code'], ethnicity['codeSystem'], ethnicity['name'])
        patient.data_elements << QDM::PatientCharacteristicEthnicity.new(data_element_codes: [code])
      end

      # Convert patient characteristic expired.
      expired = record.deathdate
      if expired
        expired_datetime = DateTime.strptime(expired.to_s, '%s')
        patient.data_elements << QDM::PatientCharacteristicExpired.new(expired_datetime: expired_datetime)
      end

      # Convert patient characteristic payer.
      insurance_providers = record.insurance_providers
      insurance_providers.each do |payer|
        start_time = DateTime.strptime(payer['start_time'].to_s, '%s') if payer['start_time']
        end_time = DateTime.strptime(payer['end_time'].to_s, '%s') if payer['end_time']
        relevant_period = QDM::Interval.new(start_time, end_time)
        if start_time || end_time
          patient.data_elements << QDM::PatientCharacteristicPayer.new(relevant_period: relevant_period)
        end
      end

      # Convert patient characteristic race.
      race = record.race
      if race
        code = QDM::Code.new(race['code'], race['codeSystem'], race['name'])
        patient.data_elements << QDM::PatientCharacteristicRace.new(data_element_codes: [code])
      end

      # Convert patient characteristic sex.
      sex = record.gender
      if sex
        code = QDM::Code.new(sex, 'Administrative sex (HL7)')
        patient.data_elements << QDM::PatientCharacteristicSex.new(data_element_codes: [code])
      end

      # Convert remaining metadata.
      patient.birth_datetime = DateTime.strptime(record.birthdate.to_s, '%s') if record.birthdate
      patient.given_names = record.first ? [record.first] : []
      patient.family_name = record.last if record.last
      patient.bundle_id = record.bundle_id if record.bundle_id

      patient
    end
  end
end
