# CQM Converter module for HDS models.
module CQM::Converter
  # CQM Converter class utilities.
  class Utils
    # Convert QDM codes structure to HDS codes structure.
    def self.qdm_codes_to_hds_codes(qdm_codes)
      codes = {}
      qdm_codes.each do |qdm_code|
        qdm_code = qdm_code.stringify_keys
        code_system = qdm_code['codeSystem']
        code_system = qdm_code['code_system'] if qdm_code['code_system']
        codes[code_system] = [] unless codes.key? code_system
        codes[code_system] << qdm_code['code'] if qdm_code['code']
      end
      codes
    end

    # Convert HDS codes structure to QDM codes structure.
    def self.hds_codes_to_qdm_codes(hds_codes)
      qdm_codes = []
      hds_codes.each do |code_system, codes|
        codes.each do |code|
          qdm_codes << { codeSystem: code_system, code: code }
        end
      end
      qdm_codes
    end

    # This helper method looks at the current state of cqm-models, and builds a hash of
    # datatype models and their attributes.
    def self.gather_qdm_model_attrs
      qdm_model_attrs = {}
      QDM.constants.each do |model|
        if QDM.const_get(model).respond_to?('fields')
          qdm_model_attrs[model.to_s] = QDM.const_get(model).fields.keys.map! { |a| a.camelize(:lower) }
        end
        if QDM.const_get(model).respond_to?('embedded_relations')
          qdm_model_attrs[model.to_s].concat(QDM.const_get(model).embedded_relations.keys.map! { |a| a.camelize(:lower) })
        end
      end
      # TODO: This field is currently not supported. See:
      # https://github.com/projecttacoma/cql_qdm_patientapi/search?q=does+not+currently+support
      qdm_model_attrs['PatientCharacteristicExpired'].delete('cause')
      qdm_model_attrs
    end

    # Parse the cql_qdm_patientapi datatypes to infer how to construct corresponding
    # HDS entries.
    def self.gather_qdm_to_hds_mappings(qdm_model_attrs = nil)
      qdm_model_attrs = gather_qdm_model_attrs if qdm_model_attrs.nil?
      cql_qdm_patientapi_spec = Gem::Specification.find_by_name('cql_qdm_patientapi')
      datatypes = Dir.glob(cql_qdm_patientapi_spec.gem_dir + '/app/assets/javascripts/datatypes/*.coffee')
      # Read in all datatypes
      datatypes_contents = ''
      datatypes.each do |datatype|
        datatypes_contents += File.read(datatype) + "\n"
      end
      datatypes_contents += 'class'
      # Construct the mappings
      qdm_to_hds_mappings = {}
      qdm_model_attrs.each do |datatype, attributes|
        datatype_pattern = /#{datatype} extends CQL_QDM.QDMDatatype.*?class/m
        next unless (dc_class = datatype_pattern.match(datatypes_contents))
        qdm_to_hds_mappings[datatype] = {}
        attributes.each do |attribute|
          attribute_pattern = /@_#{attribute}(Low|High| ).*?@entry.*?$/
          dc_class.to_s.to_enum(:scan, attribute_pattern).map do
            dc_attr = Regexp.last_match
            # Handle possible mixed values.
            if dc_attr.to_s.include? 'Low'
              qdm_to_hds_mappings[datatype][attribute] = {} unless qdm_to_hds_mappings[datatype][attribute]
              qdm_to_hds_mappings[datatype][attribute][:low] = dc_attr.to_s[/@entry.(.*?)(\)|$|\?)/m, 1]
            elsif dc_attr.to_s.include? 'High'
              qdm_to_hds_mappings[datatype][attribute] = {} unless qdm_to_hds_mappings[datatype][attribute]
              qdm_to_hds_mappings[datatype][attribute][:high] = dc_attr.to_s[/@entry.(.*?)(\)|$|\?)/m, 1]
            else
              qdm_to_hds_mappings[datatype][attribute] = dc_attr.to_s[/@entry.(.*?)(\)|$|\?)/m, 1]
            end
          end
        end
      end
      qdm_to_hds_mappings
    end

    # Builds JavaScript to assist the HDS Record to QDM Patient conversion.
    def self.hds_to_qdm_js(js_dependencies, record, qdm_model_attrs)
      record_json = JSON.parse(record.to_json)
      # Bonnie changes start_date and end_date in the front end before calculation,
      # and this is what is expected by the cql_qdm_patientapi, so make that change
      # before generating the executable JavaScript.
      record_json = record_json.deep_transform_keys { |key| key.to_s == 'start_date' ? 'start_time' : key }
      record_json = record_json.deep_transform_keys { |key| key.to_s == 'end_date' ? 'end_time' : key }
      <<-JS
        window = {};
        #{js_dependencies};
        function PatientWrapper() {
        }
        PatientWrapper.prototype.get = function(attr) {
          const contents = #{record_json.to_json};
          return contents[attr];
        }
        cql = window.cql;
        patient = new CQL_QDM.CQLPatient(new PatientWrapper());
        raw_datatypes = patient.buildDatatypes();
        qdm_model_attrs = #{qdm_model_attrs.to_json};
        processed_datatypes = {};
        // Loop over each QDM datatype.
        Object.keys(raw_datatypes).forEach(function(key) {
          processed_datatypes[key] = [];
          // Collect the values of the QDM attributes.
          raw_datatypes[key].forEach(function(datatype) {
            results = {};
            qdm_model_attrs[datatype.constructor.name].forEach(function(method) {
              // Call the datatype attribute method to get its value.
              if (datatype[method]) {
                result = datatype[method]();
                // Handle CQL execution engine type results.
                if (result && result['toJSON']) {
                  results[method] = result.toJSON();
                } else {
                  results[method] = result;
                }
              }
            });
            // Add codes to result.
            results['dataElementCodes'] = datatype['getCode']();
            // Add description to result.
            results['description'] = datatype['entry']['description'];
            // Add oid to result.
            results['hqmfOid'] = datatype['entry']['oid'];

            processed_datatypes[key].push(results);
          });
        });
        return processed_datatypes;
      JS
    end

    # Adjust improper date times from the cql_qdm_patientapi.
    def self.date_time_adjuster(results)
      if results.is_a?(Hash) && results.key?('year') && results.key?('minute')
        DateTime.new(results['year'], results['month'], results['day'], results['hour'], results['minute'], results['second'], results['millisecond']).to_s
      elsif results.is_a?(Hash)
        results.each do |key, value|
          results[key] = date_time_adjuster(value)
        end
      elsif results.is_a?(Array)
        results.map! { |result| date_time_adjuster(result) }
      else
        results
      end
    end

    # Remove any 'infinity' dates. The cql_qdm_patientapi adds an end time
    # of 'infinity' if an event does not have an end time. Remove this when
    # converting back to HDS from QDM.
    def self.fix_infinity_dates(results)
      if results.is_a?(Hash) && results.key?('end_time')
        results.delete('end_time') if results['end_time'].to_s == '253402300799'
      elsif results.is_a?(Hash)
        results.each do |key, value|
          results[key] = fix_infinity_dates(value)
        end
      elsif results.is_a?(Array)
        results.map! { |result| fix_infinity_dates(result) }
      else
        results
      end
    end

    # Helper method to handle mismatched HDS Class names for QDM things.
    def self.qdm_to_hds_class_type(category)
      if category.to_s.include? 'diagnostic'
        'procedure'
      elsif category.to_s.include? 'physical_exam'
        'procedure'
      elsif category.to_s.include? 'intervention'
        'procedure'
      elsif category.to_s.include? 'device'
        'medical_equipment'
      elsif category.to_s.include? 'laboratory'
        'vital_sign'
      elsif category.to_s.include? 'substance'
        'medication'
      elsif category.to_s.include? 'immunization'
        'medication'
      else
        category
      end
    end
  end
end
