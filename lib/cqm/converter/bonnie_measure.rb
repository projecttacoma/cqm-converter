# CQM Converter module for HDS/Bonnie models.
module CQM::Converter
  # CQM Converter class for Bonnie CqlMeasures
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
      cqm_measure.main_cql_library = bonnie_measure.main_cql_library

      # more complicated fields
      cqm_measure.measure_scoring = if bonnie_measure.continuous_variable then 'CONTINUOUS_VARIABLE' else 'PROPORTION' end
      cqm_measure.calculation_method = if bonnie_measure.episode_of_care then 'EPISODE_OF_CARE' else 'PATIENT' end

      # cql_libraries
      bonnie_measure.elm.each_with_index do |elm, elm_index|
        #require 'pry'; binding.pry
        cql_library = CQM::CQLLibrary.new(
          library_name: elm['library']['identifier']['id'],
          library_version: elm['library']['identifier']['version'],
          elm: elm,
          cql: bonnie_measure.cql[elm_index]
        )

        cql_library.elm_annotations = bonnie_measure.elm_annotations[cql_library.library_name]

        # convert statement dependencies to new form
        bonnie_measure.cql_statement_dependencies[cql_library.library_name].each do |statement_name, dependencies|
          statement_dependency = CQM::StatementDependency.new(statement_name: statement_name)
          # TODO: consider removing duplicates
          statement_dependency.statement_references = dependencies.map do |dependency|
            CQM::StatementReference.new(library_name: dependency['library_name'], statement_name: dependency['statement_name'])
          end
          cql_library.statement_dependencies << statement_dependency
        end

        cqm_measure.cql_libraries << cql_library
      end


      cqm_measure.population_criteria = bonnie_measure.population_criteria
      cqm_measure.data_criteria = bonnie_measure.data_criteria
      cqm_measure.source_data_criteria = bonnie_measure.source_data_criteria
      cqm_measure.measure_period = bonnie_measure.measure_period
      cqm_measure.measure_attributes = bonnie_measure.measure_attributes

      # convert populations, skipping strats to be added later
      bonnie_measure.populations.each_with_index do |bonnie_population, pop_index|
        # skip if this is a stratification
        next if bonnie_population.has_key?('stratification_index')

        population_set = CQM::PopulationSet.new(
          title: bonnie_population['title'],
          id: bonnie_population['id']
        )
        
        # construct the population map and fill it
        population_map = construct_population_map(cqm_measure)
        bonnie_population.each_pair do |population_name, population_key|
          # make sure it isnt metadata or an OBSERV or SDE list
          if !['id', 'title', 'OBSERV', 'supplemental_data_elements'].include?(population_name)
            population_map[population_name.to_sym] = CQM::StatementReference.new(
              library_name: cqm_measure.main_cql_library,
              statement_name: get_cql_statement_for_bonnie_population_key(bonnie_measure.populations_cql_map, population_key)
            )
          end
        end

        population_set.populations = population_map

        # add SDEs
        if bonnie_population.has_key?('supplemental_data_elements')
          bonnie_population['supplemental_data_elements'].each do |sde_statement|
            population_set.supplemental_data_elements << CQM::StatementReference.new(
              library_name: cqm_measure.main_cql_library,
              statement_name: sde_statement
            )
          end
        end

        cqm_measure.population_sets << population_set
      end

      # add stratification info to population sets
      bonnie_measure.populations.each do |bonnie_stratification|
        if bonnie_stratification.has_key?('stratification_index')
          cqm_measure.population_sets[bonnie_stratification['population_index']].stratifications << CQM::Stratification.new(
            title: bonnie_stratification['title'],
            id: bonnie_stratification['id'],
            statement: CQM::StatementReference.new(
              library_name: cqm_measure.main_cql_library,
              statement_name: get_cql_statement_for_bonnie_population_key(bonnie_measure.populations_cql_map, bonnie_stratification['STRAT'])
            )
          )
        end
      end

      # add observation info
      bonnie_measure.observations.each do |bonnie_observation|
        observation = CQM::Observation.new(
          observation_function: CQM::StatementReference.new(
            library_name: cqm_measure.main_cql_library,
            statement_name: bonnie_observation['function_name']
          )
        )
        # add observation to each population set
        cqm_measure.population_sets.each { |population_set| population_set.observations << observation }
      end

      # composite measure fields
      if bonnie_measure.composite
        cqm_measure.composite = true
        cqm_measure.component_hqmf_set_ids = bonnie_measure.component_hqmf_set_ids
      end

      # component measure fields
      if bonnie_measure.component
        cqm_measure.component = true
        cqm_measure.composite_hqmf_set_id = bonnie_measure.composite_hqmf_set_id
      end

      cqm_measure
    end

    private
    def self.construct_population_map(cqm_measure)
      case cqm_measure.measure_scoring
      when 'PROPORTION'
        CQM::ProportionPopulationMap.new()
      when 'RATIO'
        CQM::RatioPopulationMap.new()
      when 'CONTINUOUS_VARIABLE'
        CQM::ContinuousVariablePopulationMap.new()
      when 'COHORT'
        CQM::CohortPopulationMap.new()
      else
        raise StandardError("Unknown measure scoring type encountered #{cqm_measure.measure_scoring}")
      end
    end

    def self.get_cql_statement_for_bonnie_population_key(populations_cql_map, population_key)
      if population_key.include?('_')
        pop_name, pop_index = population_key.split('_')
        pop_index = pop_index.to_i
      else
        pop_name = population_key
        pop_index = 0
      end

      populations_cql_map[pop_name][pop_index]
    end
  end
end