# CQM Converter module for HDS models.
module CQM::Converter
  # CQM Converter class for HDS based records.
  module BonnieMeasure
    # Given a bonnie model, convert it to 
    def self.to_cqm(bonnie_measure)
      cqm_measure = CQM::Measure.new()

      # basic fields
      cqm_measure.hqmf_id = bonnie_measure.hqmf_id
      cqm_measure.hqmf_set_id = bonnie_measure.hqmf_set_id
      cqm_measure.hqmf_version_number = bonnie_measure.hqmf_version_number
      cqm_measure.cms_id = bonnie_measure.cms_id
      cqm_measure.title = bonnie_measure.title
      cqm_measure.description = bonnie_measure.description
      cqm_measure.calculate_sdes = bonnie_measure.calculate_sdes

      # more complicated fields
      cqm_measure.measure_scoring = if bonnie_measure.continuous_variable then 'CONTINUOUS_VARIABLE' else 'PROPORTION' end
      cqm_measure.calculation_method = if bonnie_measure.episode_of_care then 'EPISODE_OF_CARE' else 'PATIENT' end

      # cql_libraries
      cqm_measure.cql_libraries = bonnie_measure.elm.map do |elm|
        #require 'pry'; binding.pry
        cql_library = CQM::CQLLibrary.new(
          library_name: elm['library']['identifier']['id'],
          library_version: elm['library']['identifier']['version'],
          elm: elm
        )
        
        cql_library.elm_annotations = bonnie_measure.elm_annotations[cql_library.library_name]
        
        # convert statement dependencies to new form
        bonnie_measure.cql_statement_dependencies[cql_library.library_name].each do |statement_name, dependencies|
          statement_dependency = CQM::StatementDependency.new(statement_name: statement_name)
          statement_dependency.statement_references = dependencies.map do |dependency|
            CQM::StatementReference.new(library_name: dependency['library_name'], statement_name: dependency['statement_name'])
          end
          cql_library.statement_dependencies << statement_dependency
        end

        cql_library
      end

      cqm_measure
    end
  end
end