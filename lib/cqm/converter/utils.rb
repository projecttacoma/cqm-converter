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
  end
end
