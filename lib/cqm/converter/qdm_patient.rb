# CQM Converter module for QDM models.
module CQM::Converter
  # CQM Converter class for QDM based patients.
  class QDMPatient
    # Initialize a new QDMPatient converter. NOTE: This should be done once, and then
    # used for every QDM Patient you want to convert, since it takes a few seconds
    # to initialize the conversion environment.
    def initialize
      @qdm_model_attrs = Utils.gather_qdm_model_attrs
      @qdm_to_hds_mappings = Utils.gather_qdm_to_hds_mappings(@qdm_model_attrs)
    end

    # Given a QDM patient, return a corresponding HDS record.
    def to_hds(patient)
      # Start with a new HDS record.
      record = Record.new

      # Loop over the QDM Patient's data elements, and create the corresponding
      # HDS Record Entry models on the newly created record.
      patient.data_elements.each do |data_element|
        category = data_element.category if data_element.fields.include? 'category'
        next unless category
        # Handle patient characteristics seperately.
        next if data_element.category == 'patient_characteristic'

        # Grab the QDM datatype name of this data element.
        qdm_model_name = data_element.class.name.demodulize

        # Handle mismatched HDS names for QDM things.
        category = Utils.qdm_to_hds_class_type(category)

        # Grab the corresponding HDS model we will cast this QDM model into.
        hds_model = category.camelize.constantize

        # Start with a new HDS entry.
        hds_entry = hds_model.new

        # Populate codes.
        hds_entry.codes = Utils.qdm_codes_to_hds_codes(data_element.data_element_codes)

        # Populate OID.
        hds_entry.oid = data_element.hqmf_oid

        # Populate description.
        hds_entry.description = data_element.description

        # Set type.
        hds_entry.set(_type: hds_model.to_s)

        # Set status_code.
        status = data_element.fields.include?('qdm_status') ? data_element[:qdm_status] : nil
        status = 'ordered' if status == 'order'
        hds_entry.status_code = { 'HL7 ActStatus': [status] }

        # Grab the QDM attribute mappings for this data element, and construct the
        # corresponding HDS attributes.
        hds_attrs = {}
        @qdm_to_hds_mappings[qdm_model_name].each do |qdm_attr, hds_attr|
          next if data_element[qdm_attr.underscore].nil?
          extracted_value = extractor(data_element[qdm_attr.underscore])
          if hds_attr.is_a?(Hash) && hds_attr[:low]
            # Handle something that has multiple parts.
            hds_attrs[hds_attr[:low]] = extracted_value.first
            hds_attrs[hds_attr[:high]] = extracted_value.last if hds_attr[:high]
          elsif extracted_value.is_a?(Array) && extracted_value.any? && extracted_value.first.is_a?(Hash) && extracted_value.first[:code]
            # Handle a result that is returning multiple codes.
            hds_attrs[hds_attr] = [CodedResultValue.new(codes: Utils.qdm_codes_to_hds_codes(extracted_value), description: extracted_value.first[:title])]
          elsif extracted_value.is_a?(Array)
            # Handle simple Arrays.
            hds_attrs[hds_attr] = { values: extracted_value } if extracted_value.any?
          elsif hds_attr == 'values' && extracted_value.key?(:scalar)
            # Handle a Quantity.
            hds_attrs[hds_attr] = [PhysicalQuantityResultValue.new(extracted_value)]
          elsif hds_attr == 'values' && extracted_value.key?(:code)
            # Handle a Code result.
            hds_attrs[hds_attr] = [CodedResultValue.new(codes: Utils.qdm_codes_to_hds_codes([extracted_value]), description: extracted_value[:title])]
          elsif hds_attr == 'dose'
            # Handle a dosage.
            hds_attrs[hds_attr] = dose_extractor(extracted_value)
          else
            # Nothing special.
            hds_attrs[hds_attr] = extracted_value
          end
        end

        # If there is an actual negationReason, set negationInd to true.
        if hds_attrs.key?('negationReason') && !hds_attrs['negationReason'].nil?
          hds_attrs['negationInd'] = true
        end

        # Unpack references.
        unpack_references(hds_attrs)

        # Unpack facility.
        unpack_facility(hds_attrs)

        # Unpack diagnosis.
        unpack_diagnosis(hds_attrs)

        # Unpack components.
        unpack_components(hds_attrs)

        # Communication entries need direction, which we can get from the QDM model name.
        if hds_entry._type == 'Communication'
          hds_attrs['direction'] = qdm_model_name.underscore
        end

        # Apply the attributes to the entry.
        hds_entry.set(hds_attrs)

        # Add entry to HDS record, make sure to handle tricky plural types.
        plural_category = ['medical_equipment'].include?(category) ? category : category.pluralize
        record.send(plural_category) << hds_entry unless hds_entry.codes.empty?
      end

      # Unpack patient characteristics.
      unpack_patient_characteristics(patient, record)

      # Unpack extended_data.
      unpack_extended_data(patient, record)

      record
    end

    private

    # Given something QDM model based, return a corresponding HDS
    # representation. This will operate recursively.
    def extractor(qdm_thing)
      keys = qdm_thing.symbolize_keys.keys if qdm_thing.class.to_s == 'Hash'
      if qdm_thing.nil? # Is nothing.
        nil
      elsif ['Time', 'DateTime', 'Date'].include? qdm_thing.class.to_s # Is a DateTime.
        date_time_converter(qdm_thing)
      elsif qdm_thing.is_a?(String) && date_time?(qdm_thing) # Is a DateTime.
        date_time_converter(qdm_thing)
      elsif qdm_thing.is_a?(Hash) && keys.include?(:low) # Is a QDM::Interval.
        interval_extractor(qdm_thing.symbolize_keys)
      elsif qdm_thing.is_a?(Hash) && keys.include?(:code) # Is a QDM::Code.
        code_extractor(qdm_thing.symbolize_keys)
      elsif qdm_thing.is_a?(Hash) && keys.include?(:unit) # Is a QDM::Quantity.
        quantity_extractor(qdm_thing.symbolize_keys)
      elsif qdm_thing.is_a?(Array) # Is an Array.
        qdm_thing.collect { |item| extractor(item) }
      elsif qdm_thing.is_a?(Numeric) # Is an Number.
        { units: '', scalar: qdm_thing.to_s }
      elsif qdm_thing.is_a?(String) # Is an String.
        qdm_thing
      elsif qdm_thing.is_a?(Hash)
        qdm_thing.each { |k, v| qdm_thing[k] = extractor(v) }
      else
        raise 'Unsupported type! Found: ' + qdm_thing.class.to_s
      end
    end

    # Extract a QDM::Code to something usable in HDS.
    def code_extractor(code)
      { code: code[:code], code_system: code[:code_system], title: code[:descriptor] }
    end

    # Extract a QDM::Interval to something usable in HDS.
    def interval_extractor(interval)
      # If this interval has a high of inifinity, nil it out.
      interval[:high] = nil if interval[:high] == '9999-12-31T23:59:59.99+0000'
      [extractor(interval[:low]), extractor(interval[:high])]
    end

    # Extract a QDM::Quantity to something usable in HDS.
    def quantity_extractor(quantity)
      { units: quantity[:unit], scalar: quantity[:value].to_s }
    end

    # Extract a Dose to something usable in HDS.
    def dose_extractor(dose)
      { unit: dose[:units], value: dose[:scalar].to_s }
    end

    # Convert a DateTime to something usable in HDS.
    def date_time_converter(date_time)
      date_time = DateTime.parse(date_time) if date_time.class.to_s == 'String'
      date_time.to_i
    end

    # Grab the data elements on the patient. This should only be used when there
    # is no active Mongo connection.
    def get_data_elements(patient, category, status = nil)
      matches = []
      patient.data_elements.each do |data_element|
        matches << data_element if data_element[:category] == category && (data_element[:qdm_status] == status || status.nil?)
      end
      matches
    end

    # Grab the data elements on the patient by _type. This should only be used when there
    # is no active Mongo connection.
    def get_data_elements_by_type(patient, type)
      matches = []
      patient.data_elements.each do |data_element|
        matches << data_element if data_element[:_type] == type
      end
      matches
    end

    # Check if the given string is a DateTime.
    def date_time?(date_time)
      true if DateTime.parse(date_time)
    rescue ArgumentError
      false
    end

    # Unpack components.
    def unpack_components(hds_attrs)
      return unless hds_attrs.key?('components') && !hds_attrs['components'].nil?
      hds_attrs['components']['type'] = 'COL'
      hds_attrs['components'][:values].collect do |code_value|
        code_value['code'] = code_value.delete('_code')
        code_value['result'] = { code: code_value.delete('_result'), title: code_value['code'][:title] }
        code_value['code'].delete(:title)
        code_value['result'][:code].delete(:title)
        { code: code_value }
      end
    end

    # Unpack diagnosis.
    def unpack_diagnosis(hds_attrs)
      if hds_attrs.key?('diagnosis') && !hds_attrs['diagnosis'].nil?
        unpacked = {}
        unpacked['type'] = 'COL'
        unpacked['values'] = hds_attrs['diagnosis'].collect do |diag|
          code = Utils.hds_codes_to_qdm_codes(diag.codes).first
          {
            code_system: code[:code_system],
            code: code[:code],
            title: diag.description
          }
        end
        hds_attrs['diagnosis'] = unpacked
      end
      # Remove diagnosis if principalDiagnosis is equivalent.
      return unless hds_attrs.key?('diagnosis') && hds_attrs.key?('principalDiagnosis')
      return unless hds_attrs['diagnosis']['values'] && hds_attrs['diagnosis']['values'].first == hds_attrs['principalDiagnosis']
      hds_attrs.delete('diagnosis')
    end

    # Unpack facility.
    def unpack_facility(hds_attrs)
      return unless hds_attrs.key?('facility') && !hds_attrs['facility'].nil?
      hds_attrs['facility']['type'] = 'COL'
      hds_attrs['facility'][:values].each do |value|
        value['code'] = value.delete('_code')
        value[:display] = value['code'].delete(:title)
        value[:locationPeriodHigh] = Time.at(value['_location_period'].last).utc.strftime('%m/%d/%Y %l:%M %p').split.join(' ')
        value[:locationPeriodLow] = Time.at(value['_location_period'].first).utc.strftime('%m/%d/%Y %l:%M %p').split.join(' ')
        value.delete('_location_period')
      end
    end

    # Unpack references.
    def unpack_references(hds_attrs)
      return unless hds_attrs.key?('references') && !hds_attrs['references'].nil?
      hds_attrs['references'] = hds_attrs['references'][:values].collect { |value| { referenced_id: value['value'], referenced_type: value['referenced_type'], type: value['type'] } }
    end

    # Unpack patient characteristics.
    def unpack_patient_characteristics(patient, record)
      # Convert patient characteristic birthdate.
      birthdate = get_data_elements(patient, 'patient_characteristic', 'birthdate').first
      record.birthdate = birthdate.birth_datetime if birthdate

      # Convert patient characteristic clinical trial participant.
      # TODO, Adam 4/9: The Bonnie team is working on implementing this in HDS. When that work
      # is complete, this should be updated to reflect how that looks in HDS.
      # clinical_trial_participant = get_data_elements(patient, 'patient_characteristic', 'clinical_trial_participant').first

      # Convert patient characteristic ethnicity.
      ethnicity = get_data_elements(patient, 'patient_characteristic', 'ethnicity').first
      ethnicity_code = ethnicity.data_element_codes.first.symbolize_keys if ethnicity.data_element_codes.any?
      record.ethnicity = { code: ethnicity_code[:code], name: ethnicity_code[:descriptor], codeSystem: ethnicity_code[:code_system] } if ethnicity_code

      # Convert patient characteristic expired.
      expired = get_data_elements_by_type(patient, 'QDM::PatientCharacteristicExpired').first
      record.deathdate = date_time_converter(expired.expired_datetime) if expired
      record.expired = record.deathdate if record.deathdate

      # Convert patient characteristic race.
      race = get_data_elements(patient, 'patient_characteristic', 'race').first
      race_code = race.data_element_codes.first.symbolize_keys if race.data_element_codes.any?
      record.race = { code: race_code[:code], name: race_code[:descriptor], codeSystem: race_code[:code_system] } if race_code

      # Convert patient characteristic sex.
      sex = get_data_elements_by_type(patient, 'QDM::PatientCharacteristicSex').first
      sex_code = sex.data_element_codes.first.symbolize_keys if sex.data_element_codes.any?
      record.gender = sex_code[:code] if sex

      # Convert remaining metadata.
      record.birthdate = date_time_converter(patient.birth_datetime) unless record.birthdate
      record.first = patient.given_names.first if patient.given_names.any?
      record.last = patient.family_name if patient.family_name
      record.bundle_id = patient.bundle_id if patient.bundle_id
    end

    # Unpack extended data.
    def unpack_extended_data(patient, record)
      record['type'] = patient.extended_data['type'] if patient.extended_data['type']
      record['measure_ids'] = patient.extended_data['measure_ids'] if patient.extended_data['measure_ids']
      record['source_data_criteria'] = patient.extended_data['source_data_criteria'] if patient.extended_data['source_data_criteria']
      record['expected_values'] = patient.extended_data['expected_values'] if patient.extended_data['expected_values']
      record['notes'] = patient.extended_data['notes'] if patient.extended_data['notes']
      record['is_shared'] = patient.extended_data['is_shared'] if patient.extended_data['is_shared']
      record['origin_data'] = patient.extended_data['origin_data'] if patient.extended_data['origin_data']
      record['test_id'] = patient.extended_data['test_id'] if patient.extended_data['test_id']
      record['medical_record_number'] = patient.extended_data['medical_record_number'] if patient.extended_data['medical_record_number']
      record['medical_record_assigner'] = patient.extended_data['medical_record_assigner'] if patient.extended_data['medical_record_assigner']
      record['description'] = patient.extended_data['description'] if patient.extended_data['description']
      record['description_category'] = patient.extended_data['description_category'] if patient.extended_data['description_category']
      record['insurance_providers'] = patient.extended_data['insurance_providers'] if patient.extended_data['insurance_providers']
    end
  end
end
