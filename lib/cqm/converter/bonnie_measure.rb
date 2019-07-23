# CQM Converter module for HDS/Bonnie models.
module CQM::Converter
  # CQM Converter class for Bonnie CqlMeasures
  module BonnieMeasure
    # Given a bonnie model, convert it to the new CQM measure model. including value sets if they are found
    def self.to_cqm(bonnie_measure)
      cqm_measure = shallow_copy(bonnie_measure)
      cqm_measure.source_data_criteria = convert_source_data_criteria(bonnie_measure)
      cqm_measure.source_data_criteria = cqm_measure.source_data_criteria.uniq { |sdc| [sdc.codeListId, sdc.description] }

      # cql_libraries. the order we need to match is of cql_statement_dependencies
      bonnie_measure.cql_statement_dependencies.keys.each do |library_name|
        # find the elm for this library
        bonnie_measure.elm.each_with_index do |elm, elm_index|
          # skip if this is not the library we are looking for
          next unless elm['library']['identifier']['id'] == library_name

          cql_library = CQM::CQLLibrary.new(
            library_name: elm['library']['identifier']['id'],
            library_version: elm['library']['identifier']['version'],
            elm: elm,
            elm_annotations: bonnie_measure.elm_annotations[elm['library']['identifier']['id']],
            is_top_level: bonnie_measure.elm_annotations.key?(elm['library']['identifier']['id']),
            cql: bonnie_measure.cql[elm_index]
          )
          # if this is the main library, then mark it
          if elm['library']['identifier']['id'] == cqm_measure.main_cql_library
            cql_library.is_main_library = true
          end

          # convert statement dependencies to new form
          bonnie_measure.cql_statement_dependencies[cql_library.library_name].each do |statement_name, dependencies|
            # Replace "escaped" period with period now that statement_name is no longer a key
            statement_name_fixed = statement_name.gsub '^p', '.'
            statement_dependency = CQM::StatementDependency.new(statement_name: statement_name_fixed)
            # TODO: consider removing duplicates
            statement_dependency.statement_references = dependencies.map do |dependency|
              CQM::StatementReference.new(library_name: dependency['library_name'], statement_name: dependency['statement_name'])
            end
            cql_library.statement_dependencies << statement_dependency
          end

          update_oids(cql_library)

          cqm_measure.cql_libraries << cql_library
          break
        end
      end

      # convert populations, skipping strats to be added later
      bonnie_measure.populations.each do |bonnie_population|
        # skip if this is a stratification
        next if bonnie_population.key?('stratification_index')

        population_set = CQM::PopulationSet.new(
          title: bonnie_population['title'],
          population_set_id: bonnie_population['id']
        )

        # construct the population map and fill it
        population_map = construct_population_map(cqm_measure)
        bonnie_population.each_pair do |population_name, population_key|
          # make sure it isnt metadata or an OBSERV or SDE list
          next if ['id', 'title', 'OBSERV', 'supplemental_data_elements'].include?(population_name)

          population_map[population_name.to_sym] = CQM::StatementReference.new(
            library_name: cqm_measure.main_cql_library,
            statement_name: get_cql_statement_for_bonnie_population_key(bonnie_measure.populations_cql_map, population_key),
            hqmf_id: bonnie_measure.population_criteria[population_key]['hqmf_id']
          )
        end

        population_set.populations = population_map

        # add SDEs
        if bonnie_population.key?('supplemental_data_elements')
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
        next unless bonnie_stratification.key?('stratification_index')

        cqm_measure.population_sets[bonnie_stratification['population_index']].stratifications << CQM::Stratification.new(
          title: bonnie_stratification['title'],
          stratification_id: bonnie_stratification['id'],
          statement: CQM::StatementReference.new(
            library_name: cqm_measure.main_cql_library,
            statement_name: get_cql_statement_for_bonnie_population_key(bonnie_measure.populations_cql_map, bonnie_stratification['STRAT']),
            hqmf_id: bonnie_measure.population_criteria[bonnie_stratification['STRAT']]['hqmf_id']
          ),
          hqmf_id: bonnie_measure.population_criteria[bonnie_stratification['STRAT']]['hqmf_id']
        )
      end

      convert_observations(bonnie_measure, cqm_measure.main_cql_library).each do |observation|
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

      # value sets if they exist
      unless bonnie_measure.value_sets.empty?
        cqm_measure.value_sets = CQM::Converter::HDSValueSet.list_to_cqm(bonnie_measure.value_sets, bonnie_measure.value_set_oid_version_objects)
      end

      cqm_measure
    end

    # convert bonnie measure and provide value sets to convert and attach to measure
    def self.measure_and_valuesets_to_cqm(bonnie_measure, hds_valuesets)
      cqm_measure = to_cqm(bonnie_measure)
      cqm_valuesets = CQM::Converter::HDSValueSet.list_to_cqm(hds_valuesets, bonnie_measure.value_set_oid_version_objects)
      cqm_measure.value_sets = cqm_valuesets
      cqm_measure
    end

    def self.update_oids(cql_library)
      name_oid_hash = JSON.parse(File.read(File.join(File.dirname(__FILE__), 'name_oid_map.json')))
      return unless cql_library['elm']['library'] && cql_library['elm']['library']['codeSystems'] && cql_library['elm']['library']['codeSystems']['def']

      cql_library['elm']['library']['codeSystems']['def'].each do |codesystem|
        if name_oid_hash[codesystem['id']].nil?
          # puts 'ERROR: Could Not Resolve OID For Code System ' + codesystem['id']
        else
          codesystem['id'] = name_oid_hash[codesystem['id']]
        end
      end
    end
  end
end

def shallow_copy(bonnie_measure)
  cqm_measure = CQM::Measure.new

  # basic fields
  cqm_measure.hqmf_id = bonnie_measure.hqmf_id
  cqm_measure.hqmf_set_id = bonnie_measure.hqmf_set_id
  cqm_measure.hqmf_version_number = bonnie_measure.hqmf_version_number
  cqm_measure.cms_id = bonnie_measure.cms_id
  cqm_measure.title = bonnie_measure.title
  cqm_measure.description = bonnie_measure.description
  cqm_measure.calculate_sdes = bonnie_measure.calculate_sdes
  cqm_measure.main_cql_library = bonnie_measure.main_cql_library
  cqm_measure.population_criteria = bonnie_measure.population_criteria
  cqm_measure.measure_period = bonnie_measure.measure_period
  cqm_measure.measure_attributes = bonnie_measure.measure_attributes

  # more complicated fields
  cqm_measure.measure_scoring = bonnie_measure.continuous_variable ? 'CONTINUOUS_VARIABLE' : 'PROPORTION'
  cqm_measure.calculation_method = bonnie_measure.episode_of_care ? 'EPISODE_OF_CARE' : 'PATIENT'

  cqm_measure
end

def convert_source_data_criteria(bonnie_measure)
  @map_definition_and_status_to_model ||= JSON.parse(File.read(File.join(File.dirname(__FILE__), 'map_definition_and_status_to_model.json')))
  converted_source_data_criteria = bonnie_measure.source_data_criteria.map do |_, sdc|
    key = "#{sdc['definition']}::#{sdc['status']}"
    if @map_definition_and_status_to_model[key].present?
      model_name = @map_definition_and_status_to_model[key]['model_name']
      if model_name == 'PatientCharacteristicExpired' || model_name == 'PatientCharacteristicBirthdate'
        if bonnie_measure.value_set_oids.any? { |s| s.include?('drc-') }
          bonnie_measure.elm.each do |elm|
            # Loops over all single codes and saves them as fake valuesets.
            (elm.dig('library','codes','def') || []).each do |code_reference|
              birthdate_names = ['birthdate', 'birth date']
              dead_names = ['dead', 'expired']
              if (model_name == 'PatientCharacteristicExpired' && dead_names.include?(code_reference['name'].downcase)) || (model_name == 'PatientCharacteristicBirthdate' && birthdate_names.include?(code_reference['name'].downcase))
                # look up the referenced code system
                code_system_def = elm['library']['codeSystems']['def'].find { |code_sys| code_sys['name'] == code_reference['codeSystem']['name'] }
                # Generate a unique number as our fake "oid" based on parameters that identify the DRC
                code_system_name = code_system_def['id']
                code_system_version = code_system_def['version']

                # Generate a unique number as our fake "oid" based on parameters that identify the DRC
                code_hash = "drc-" + Digest::SHA2.hexdigest("#{code_system_name} #{code_reference['id']} #{code_reference['name']} #{code_system_version}")
                if bonnie_measure.value_set_oids.any? { |s| s == code_hash }
                  sdc['code_list_id'] = code_hash
                end
              end
            end
          end
        end
      end
      QDM.const_get(model_name).new(
        description: sdc['description'],
        codeListId: sdc['code_list_id']
      )
    else
      # printf ''
      puts "\nRemoving SDC #{key} from measure".light_blue
    end
  end
  converted_source_data_criteria
end

def convert_observations(bonnie_measure, main_cql_library)
  observations = []
  bonnie_measure&.observations&.each_with_index do |bonnie_observation, observation_index|
    # if this happens to be a multiple observation measure _this is unlikely_ we need to make a key to grab the proper hqmf_id
    observation_population_key = observation_index.positive? ? "OBSERV_#{observation_index}" : 'OBSERV'
    observation_hqmf_id = bonnie_measure.population_criteria[observation_population_key]['hqmf_id']

    observations << CQM::Observation.new(
      observation_function: CQM::StatementReference.new(
        library_name: main_cql_library,
        statement_name: bonnie_observation['function_name'],
        hqmf_id: observation_hqmf_id
      ),
      observation_parameter: CQM::StatementReference.new(
        library_name: main_cql_library,
        statement_name: bonnie_observation['parameter'],
        hqmf_id: observation_hqmf_id
      ),
      hqmf_id: observation_hqmf_id
    )
  end
  observations
end

def construct_population_map(cqm_measure)
  case cqm_measure.measure_scoring
  when 'PROPORTION'
    CQM::ProportionPopulationMap.new
  when 'RATIO'
    CQM::RatioPopulationMap.new
  when 'CONTINUOUS_VARIABLE'
    CQM::ContinuousVariablePopulationMap.new
  when 'COHORT'
    CQM::CohortPopulationMap.new
  else
    raise StandardError, "Unknown measure scoring type encountered #{cqm_measure.measure_scoring}"
  end
end

def get_cql_statement_for_bonnie_population_key(populations_cql_map, population_key)
  if population_key.include?('_')
    pop_name, pop_index = population_key.split('_')
    pop_index = pop_index.to_i
  else
    pop_name = population_key
    pop_index = 0
  end

  populations_cql_map[pop_name][pop_index]
end
