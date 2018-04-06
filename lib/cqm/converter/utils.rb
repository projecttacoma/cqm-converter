# CQM Converter module for HDS models.
module CQM::Converter
  # CQM Converter class utilities.
  class Utils
    # This helper method looks at the current state of cqm-models, and builds a hash of
    # datatype models and their attributes.
    def self.gather_qdm_model_attrs
      datatype_attributes = {}
      QDM.constants.each do |model|
        if QDM.const_get(model).respond_to?('fields')
          datatype_attributes[model.to_s] = QDM.const_get(model).fields.keys.map! { |a| a.camelize(:lower) }
        end
      end
      datatype_attributes
    end

    # Builds JavaScript to assist the HDS Record to QDM Patient conversion.
    def self.hds_to_qdm_js(js_dependencies, record, datatype_attributes)
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
        datatype_attributes = #{datatype_attributes.to_json};
        processed_datatypes = {};
        // Loop over each QDM datatype
        Object.keys(raw_datatypes).forEach(function(key) {
          processed_datatypes[key] = [];
          // Collect the values of the QDM attributes
          raw_datatypes[key].forEach(function(datatype) {
            results = {};
            datatype_attributes[datatype.constructor.name].forEach(function(method) {
              // Call the datatype attribute method to get its value
              if (datatype[method]) {
                if (datatype[method]() && datatype[method]()['toJSON']) {
                  results[method] = datatype[method]().toJSON();
                } else {
                  results[method] = datatype[method]();
                }
              }
            });
            // Add codes to result
            results['dataElementCodes'] = datatype['getCode']();
            // Add description to result
            results['description'] = datatype['entry']['description'];
            processed_datatypes[key].push(results);
          });
        });
        return processed_datatypes;
      JS
    end
  end
end
