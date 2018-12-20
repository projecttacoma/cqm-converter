require 'spec_helper'

RSpec.describe CQM::Converter::BonnieMeasure do
  it 'converts proportion measure with single population set' do
    bonnie_measure = CqlMeasure.new.from_json(File.read('spec/fixtures/bonnie/core_measures/CMS134v6.json'))
    cqm_measure = CQM::Converter::BonnieMeasure.to_cqm(bonnie_measure)

    expect(cqm_measure).to_not be_nil
    expect(cqm_measure.measure_scoring).to eq('PROPORTION')
    expect(cqm_measure.calculation_method).to eq('PATIENT')

    expect(cqm_measure.cql_libraries.size).to eq(3)

    # check the main library name and find new library structure using it
    expect(cqm_measure.main_cql_library).to eq('DiabetesMedicalAttentionforNephropathy')
    main_library = cqm_measure.cql_libraries.select(&:is_main_library).first

    # check the new library structure
    expect(main_library).to_not be_nil
    expect(main_library.library_name).to eq('DiabetesMedicalAttentionforNephropathy')
    expect(main_library.library_version).to eq('6.1.003')
    expect(main_library.statement_dependencies.size).to eq(18)
    expect(main_library.elm_annotations).to eq(bonnie_measure.elm_annotations['DiabetesMedicalAttentionforNephropathy'])
    expect(main_library.elm).to eq(bonnie_measure.elm[0])
    expect(main_library.cql).to start_with('library DiabetesMedicalAttentionforNephropathy')
    expect(main_library.is_main_library).to eq(true)

    # check the references used by the "Initial Population"
    ipp_dep = main_library.statement_dependencies.select { |dep| dep.statement_name == 'Initial Population' }.first
    expect(ipp_dep).to_not be_nil
    expect(ipp_dep.statement_references.size).to eq(3)
    expect(ipp_dep.statement_references.map(&:statement_name)).to include('Qualifying Encounters')

    # Legacy fields that may be removed later
    expect(cqm_measure.population_criteria).to eq(bonnie_measure.population_criteria)
    expect(cqm_measure.data_criteria).to eq(bonnie_measure.data_criteria)
    expect(cqm_measure.source_data_criteria).to eq(bonnie_measure.source_data_criteria)
    expect(cqm_measure.measure_period).to eq(bonnie_measure.measure_period)
    expect(cqm_measure.measure_attributes).to eq(bonnie_measure.measure_attributes)

    # check population set
    expect(cqm_measure.population_sets.size).to eq(1)
    population_set = cqm_measure.population_sets[0]
    expect(population_set.id).to eq('PopulationCriteria1')
    expect(population_set.title).to eq('Population Criteria Section')
    expect(population_set.populations).to be_instance_of(CQM::ProportionPopulationMap)
    expect(population_set.populations.IPP.statement_name).to eq('Initial Population')
  end

  it 'converts proportion measure with three population sets' do
    bonnie_measure = CqlMeasure.new.from_json(File.read('spec/fixtures/bonnie/core_measures/CMS160v6.json'))
    cqm_measure = CQM::Converter::BonnieMeasure.to_cqm(bonnie_measure)

    expect(cqm_measure).to_not be_nil
    expect(cqm_measure.measure_scoring).to eq('PROPORTION')
    expect(cqm_measure.calculation_method).to eq('PATIENT')

    expect(cqm_measure.cql_libraries.size).to eq(1)

    # check the main library name and find new library structure using it
    expect(cqm_measure.main_cql_library).to eq('DepressionUtilizationofthePHQ9Tool')
    main_library = cqm_measure.cql_libraries.select(&:is_main_library).first

    # check the new library structure
    expect(main_library).to_not be_nil
    expect(main_library.library_name).to eq('DepressionUtilizationofthePHQ9Tool')
    expect(main_library.library_version).to eq('6.1.001')
    expect(main_library.statement_dependencies.size).to eq(33)
    expect(main_library.elm_annotations).to eq(bonnie_measure.elm_annotations['DepressionUtilizationofthePHQ9Tool'])
    expect(main_library.elm).to eq(bonnie_measure.elm[0])
    expect(main_library.cql).to start_with('library DepressionUtilizationofthePHQ9Tool')
    expect(main_library.is_main_library).to eq(true)

    # check the references used by the "Initial Population 1"
    ipp_dep = main_library.statement_dependencies.select { |dep| dep.statement_name == 'Initial Population 1' }.first
    expect(ipp_dep).to_not be_nil
    expect(ipp_dep.statement_references.size).to eq(3)
    expect(ipp_dep.statement_references.map(&:statement_name)).to include('Depression Face to Face Encounter 1')

    # Legacy fields that may be removed later
    expect(cqm_measure.population_criteria).to eq(bonnie_measure.population_criteria)
    expect(cqm_measure.data_criteria).to eq(bonnie_measure.data_criteria)
    expect(cqm_measure.source_data_criteria).to eq(bonnie_measure.source_data_criteria)
    expect(cqm_measure.measure_period).to eq(bonnie_measure.measure_period)
    expect(cqm_measure.measure_attributes).to eq(bonnie_measure.measure_attributes)

    # check population set 1
    expect(cqm_measure.population_sets.size).to eq(3)
    population_set = cqm_measure.population_sets[0]
    expect(population_set.id).to eq('PopulationCriteria1')
    expect(population_set.title).to eq('Population Criteria Section 1')
    expect(population_set.populations).to be_instance_of(CQM::ProportionPopulationMap)
    expect(population_set.populations.IPP.statement_name).to eq('Initial Population 1')

    population_set = cqm_measure.population_sets[1]
    expect(population_set.id).to eq('PopulationCriteria2')
    expect(population_set.title).to eq('Population Criteria Section 2')
    expect(population_set.populations).to be_instance_of(CQM::ProportionPopulationMap)
    expect(population_set.populations.DENOM.statement_name).to eq('Denominator 2')

    population_set = cqm_measure.population_sets[2]
    expect(population_set.id).to eq('PopulationCriteria3')
    expect(population_set.title).to eq('Population Criteria Section 3')
    expect(population_set.populations).to be_instance_of(CQM::ProportionPopulationMap)
    expect(population_set.populations.NUMER.statement_name).to eq('Numerator 3')
  end

  it 'converts continuous variable episode measure and valuesets using bonnie measure.value_sets getter' do
    dump_database
    bonnie_measure = CqlMeasure.new.from_json(File.read('spec/fixtures/bonnie/core_measures/CMS32v7.json'))
    hds_value_sets = JSON.parse(File.read('spec/fixtures/hds/valuesets/core_measures/CMS32v7.json')).map do |vs_json|
      HealthDataStandards::SVS::ValueSet.new(vs_json)
    end
    bonnie_measure.save
    hds_value_sets.each(&:save)

    cqm_measure = CQM::Converter::BonnieMeasure.to_cqm(bonnie_measure)
    # check valuesets
    expect(cqm_measure.value_sets.size).to eq(hds_value_sets.size)
  end

  it 'converts continuous variable episode measure and valuesets with single population set and three stratifications' do
    bonnie_measure = CqlMeasure.new.from_json(File.read('spec/fixtures/bonnie/core_measures/CMS32v7.json'))
    hds_value_sets = JSON.parse(File.read('spec/fixtures/hds/valuesets/core_measures/CMS32v7.json')).map do |vs_json|
      HealthDataStandards::SVS::ValueSet.new(vs_json)
    end

    cqm_measure = CQM::Converter::BonnieMeasure.measure_and_valuesets_to_cqm(bonnie_measure, hds_value_sets)

    expect(cqm_measure).to_not be_nil
    expect(cqm_measure.measure_scoring).to eq('CONTINUOUS_VARIABLE')
    expect(cqm_measure.calculation_method).to eq('EPISODE_OF_CARE')

    expect(cqm_measure.cql_libraries.size).to eq(1)

    # check the main library name and find new library structure using it
    expect(cqm_measure.main_cql_library).to eq('MedianTimefromEDArrivaltoEDDepartureforDischargedEDPatients')
    main_library = cqm_measure.cql_libraries.select(&:is_main_library).first

    # check the new library structure
    expect(main_library).to_not be_nil
    expect(main_library.library_name).to eq('MedianTimefromEDArrivaltoEDDepartureforDischargedEDPatients')
    expect(main_library.library_version).to eq('7.2.002')
    expect(main_library.statement_dependencies.size).to eq(13)
    expect(main_library.elm_annotations).to eq(bonnie_measure.elm_annotations['MedianTimefromEDArrivaltoEDDepartureforDischargedEDPatients'])
    expect(main_library.elm).to eq(bonnie_measure.elm[0])
    expect(main_library.cql).to start_with('library MedianTimefromEDArrivaltoEDDepartureforDischargedEDPatients')
    expect(main_library.is_main_library).to eq(true)

    # check the references used by the "Initial Population"
    ipp_dep = main_library.statement_dependencies.select { |dep| dep.statement_name == 'Initial Population' }.first
    expect(ipp_dep).to_not be_nil
    expect(ipp_dep.statement_references.size).to eq(1)
    expect(ipp_dep.statement_references.map(&:statement_name)).to include('ED Visit')

    # Legacy fields that may be removed later
    expect(cqm_measure.population_criteria).to eq(bonnie_measure.population_criteria)
    expect(cqm_measure.data_criteria).to eq(bonnie_measure.data_criteria)
    expect(cqm_measure.source_data_criteria).to eq(bonnie_measure.source_data_criteria)
    expect(cqm_measure.measure_period).to eq(bonnie_measure.measure_period)
    expect(cqm_measure.measure_attributes).to eq(bonnie_measure.measure_attributes)

    # check population set
    expect(cqm_measure.population_sets.size).to eq(1)
    population_set = cqm_measure.population_sets[0]
    expect(population_set.id).to eq('PopulationCriteria1')
    expect(population_set.title).to eq('Population Criteria Section')
    expect(population_set.populations).to be_instance_of(CQM::ContinuousVariablePopulationMap)
    expect(population_set.populations.IPP.statement_name).to eq('Initial Population')
    expect(population_set.populations.MSRPOPL.statement_name).to eq('Measure Population')
    expect(population_set.populations.MSRPOPLEX.statement_name).to eq('Measure Population Exclusions')
    # check stratifications
    expect(population_set.stratifications.size).to eq(3)
    expect(population_set.stratifications[0].id).to eq('PopulationCriteria1 - Stratification 1')
    expect(population_set.stratifications[0].title).to eq('Stratification 1')
    expect(population_set.stratifications[0].statement.statement_name).to eq('Stratification 1')
    expect(population_set.stratifications[1].id).to eq('PopulationCriteria1 - Stratification 2')
    expect(population_set.stratifications[1].title).to eq('Stratification 2')
    expect(population_set.stratifications[1].statement.statement_name).to eq('Stratification 2')
    expect(population_set.stratifications[2].id).to eq('PopulationCriteria1 - Stratification 3')
    expect(population_set.stratifications[2].title).to eq('Stratification 3')
    expect(population_set.stratifications[2].statement.statement_name).to eq('Stratification 3')
    # check observation
    expect(population_set.observations.size).to eq(1)
    expect(population_set.observations[0].observation_function.statement_name).to eq('Measure Observation')

    # check valuesets
    expect(cqm_measure.value_sets.size).to eq(hds_value_sets.size)
  end

  it 'converts episode of care measure with single population set' do
    bonnie_measure = CqlMeasure.new.from_json(File.read('spec/fixtures/bonnie/core_measures/CMS177v6.json'))
    cqm_measure = CQM::Converter::BonnieMeasure.to_cqm(bonnie_measure)

    expect(cqm_measure).to_not be_nil
    expect(cqm_measure.measure_scoring).to eq('PROPORTION')
    expect(cqm_measure.calculation_method).to eq('EPISODE_OF_CARE')

    expect(cqm_measure.cql_libraries.size).to eq(1)

    # check the main library name and find new library structure using it
    expect(cqm_measure.main_cql_library).to eq('ChildandAdolescentMajorDepressiveDisorderMDDSuicideRiskAssessment')
    main_library = cqm_measure.cql_libraries.select(&:is_main_library).first

    # check the new library structure
    expect(main_library).to_not be_nil
    expect(main_library.library_name).to eq('ChildandAdolescentMajorDepressiveDisorderMDDSuicideRiskAssessment')
    expect(main_library.library_version).to eq('6.0.002')
    expect(main_library.statement_dependencies.size).to eq(9)
    expect(main_library.elm_annotations).to eq(bonnie_measure.elm_annotations['ChildandAdolescentMajorDepressiveDisorderMDDSuicideRiskAssessment'])
    expect(main_library.elm).to eq(bonnie_measure.elm[0])
    expect(main_library.cql).to start_with('library ChildandAdolescentMajorDepressiveDisorderMDDSuicideRiskAssessment')
    expect(main_library.is_main_library).to eq(true)

    # check the references used by the "Initial Population"
    ipp_dep = main_library.statement_dependencies.select { |dep| dep.statement_name == 'Initial Population' }.first
    expect(ipp_dep).to_not be_nil
    expect(ipp_dep.statement_references.size).to eq(1)
    expect(ipp_dep.statement_references.map(&:statement_name)).to include('Encounter with Major Depressive Disorder Diagnosis')

    # Legacy fields that may be removed later
    expect(cqm_measure.population_criteria).to eq(bonnie_measure.population_criteria)
    expect(cqm_measure.data_criteria).to eq(bonnie_measure.data_criteria)
    expect(cqm_measure.source_data_criteria).to eq(bonnie_measure.source_data_criteria)
    expect(cqm_measure.measure_period).to eq(bonnie_measure.measure_period)
    expect(cqm_measure.measure_attributes).to eq(bonnie_measure.measure_attributes)

    # check population set
    expect(cqm_measure.population_sets.size).to eq(1)
    population_set = cqm_measure.population_sets[0]
    expect(population_set.id).to eq('PopulationCriteria1')
    expect(population_set.title).to eq('Population Criteria Section')
    expect(population_set.populations).to be_instance_of(CQM::ProportionPopulationMap)
    expect(population_set.populations.IPP.statement_name).to eq('Initial Population')
    expect(population_set.populations.DENOM.statement_name).to eq('Denominator')
    expect(population_set.populations.DENEX).to be_nil
    expect(population_set.populations.NUMER.statement_name).to eq('Numerator')
    # check stratifications
    expect(population_set.stratifications.size).to eq(0)
    # check observation
    expect(population_set.observations.size).to eq(0)
    # check SDEs
    expect(population_set.supplemental_data_elements.size).to eq(0)
  end

  it 'converts composite measure' do
    bonnie_measure = CqlMeasure.new.from_json(File.read('spec/fixtures/bonnie/AWA_composite.json'))
    cqm_measure = CQM::Converter::BonnieMeasure.to_cqm(bonnie_measure)

    expect(cqm_measure).to_not be_nil
    expect(cqm_measure.measure_scoring).to eq('CONTINUOUS_VARIABLE')
    expect(cqm_measure.calculation_method).to eq('PATIENT')

    expect(cqm_measure.cql_libraries.size).to eq(20)
    expect(cqm_measure.cql_libraries.select(&:is_main_library).size).to eq(1)
    expect(cqm_measure.cql_libraries.reject(&:is_main_library).size).to eq(19)

    # check the main library name and find new library structure using it
    expect(cqm_measure.main_cql_library).to eq('AWATestComposite')
    main_library = cqm_measure.cql_libraries.select(&:is_main_library).first

    # check the new library structure
    expect(main_library).to_not be_nil
    expect(main_library.library_name).to eq('AWATestComposite')
    expect(main_library.library_version).to eq('0.0.005')
    expect(main_library.statement_dependencies.size).to eq(25)
    expect(main_library.elm_annotations).to eq(bonnie_measure.elm_annotations['AWATestComposite'])
    expect(main_library.elm).to eq(bonnie_measure.elm[0])
    expect(main_library.cql).to start_with('library AWATestComposite')
    expect(main_library.is_main_library).to eq(true)

    # check the references used by the "Initial Population"
    ipp_dep = main_library.statement_dependencies.select { |dep| dep.statement_name == 'Initial Population' }.first
    expect(ipp_dep).to_not be_nil
    expect(ipp_dep.statement_references.size).to eq(7)
    expect(ipp_dep.statement_references.map(&:statement_name)).to include('Initial Population')

    # Legacy fields that may be removed later
    expect(cqm_measure.population_criteria).to eq(bonnie_measure.population_criteria)
    expect(cqm_measure.data_criteria).to eq(bonnie_measure.data_criteria)
    expect(cqm_measure.source_data_criteria).to eq(bonnie_measure.source_data_criteria)
    expect(cqm_measure.measure_period).to eq(bonnie_measure.measure_period)
    expect(cqm_measure.measure_attributes).to eq(bonnie_measure.measure_attributes)

    # check population set
    expect(cqm_measure.population_sets.size).to eq(1)
    population_set = cqm_measure.population_sets[0]
    expect(population_set.id).to eq('PopulationCriteria1')
    expect(population_set.title).to eq('Population Criteria Section')
    expect(population_set.populations).to be_instance_of(CQM::ContinuousVariablePopulationMap)
    expect(population_set.populations.IPP.statement_name).to eq('Initial Population')
    expect(population_set.populations.MSRPOPL.statement_name).to eq('Measure Population')
    expect(population_set.populations.MSRPOPLEX.statement_name).to eq('Measure Population Exclusions')
    # check stratifications
    expect(population_set.stratifications.size).to eq(0)
    # check observation
    expect(population_set.observations.size).to eq(1)
    expect(population_set.observations[0].observation_function.statement_name).to eq('Measure Observation')
    # check SDEs
    expect(population_set.supplemental_data_elements.map(&:statement_name)).to eq(
      [
        'SDE Ethnicity',
        'SDE Payer',
        'SDE Race',
        'SDE Sex'
      ]
    )

    # check composite measure fields
    expect(cqm_measure.composite).to eq(true)
    expect(cqm_measure.component).to eq(false)
    expect(cqm_measure.component_hqmf_set_ids).to eq(
      [
        '244B4F52-C9CA-45AA-8BDB-2F005DA05BFC&E22EA997-4EC1-4ED2-876C-3671099CB325',
        '244B4F52-C9CA-45AA-8BDB-2F005DA05BFC&7B905B21-D904-454F-885B-9CE5D19674E3',
        '244B4F52-C9CA-45AA-8BDB-2F005DA05BFC&920D5B27-DF5A-4770-BD60-FC4EE251C4D2',
        '244B4F52-C9CA-45AA-8BDB-2F005DA05BFC&3000797E-11B1-4F62-A078-341A4002A11C',
        '244B4F52-C9CA-45AA-8BDB-2F005DA05BFC&5B20AFEA-D4AF-4F7A-A5A3-F1F6165B9E5F',
        '244B4F52-C9CA-45AA-8BDB-2F005DA05BFC&F03324C2-9147-457B-BC34-811BB7859C91',
        '244B4F52-C9CA-45AA-8BDB-2F005DA05BFC&BA108B7B-90B4-4692-B1D0-5DB554D2A1A2'
      ]
    )
  end

  it 'converts component measure' do
    bonnie_measure = CqlMeasure.new(JSON.parse(File.read('spec/fixtures/bonnie/AWA_components.json'))[0])
    cqm_measure = CQM::Converter::BonnieMeasure.to_cqm(bonnie_measure)

    expect(cqm_measure).to_not be_nil
    expect(cqm_measure.measure_scoring).to eq('PROPORTION')
    expect(cqm_measure.calculation_method).to eq('PATIENT')

    expect(cqm_measure.cql_libraries.size).to eq(2)

    # check the main library name and find new library structure using it
    expect(cqm_measure.main_cql_library).to eq('AnnualWellnessAssessmentPreventiveCareScreeningforFallsRisk')
    main_library = cqm_measure.cql_libraries.select(&:is_main_library).first

    # check the new library structure
    expect(main_library).to_not be_nil
    expect(main_library.library_name).to eq('AnnualWellnessAssessmentPreventiveCareScreeningforFallsRisk')
    expect(main_library.library_version).to eq('0.4.000')
    expect(main_library.statement_dependencies.size).to eq(14)
    expect(main_library.elm_annotations).to eq(bonnie_measure.elm_annotations['AnnualWellnessAssessmentPreventiveCareScreeningforFallsRisk'])
    expect(main_library.elm).to eq(bonnie_measure.elm[0])
    expect(main_library.cql).to start_with('library AnnualWellnessAssessmentPreventiveCareScreeningforFallsRisk')
    expect(main_library.is_main_library).to eq(true)

    # check the references used by the "Initial Population"
    ipp_dep = main_library.statement_dependencies.select { |dep| dep.statement_name == 'Initial Population' }.first
    expect(ipp_dep).to_not be_nil
    expect(ipp_dep.statement_references.size).to eq(2)
    expect(ipp_dep.statement_references.map(&:statement_name)).to include('Annual Wellness Visit Encounter')

    # Legacy fields that may be removed later
    expect(cqm_measure.population_criteria).to eq(bonnie_measure.population_criteria)
    expect(cqm_measure.data_criteria).to eq(bonnie_measure.data_criteria)
    expect(cqm_measure.source_data_criteria).to eq(bonnie_measure.source_data_criteria)
    expect(cqm_measure.measure_period).to eq(bonnie_measure.measure_period)
    expect(cqm_measure.measure_attributes).to eq(bonnie_measure.measure_attributes)

    # check population set
    expect(cqm_measure.population_sets.size).to eq(1)
    population_set = cqm_measure.population_sets[0]
    expect(population_set.id).to eq('PopulationCriteria1')
    expect(population_set.title).to eq('Population Criteria Section')
    expect(population_set.populations).to be_instance_of(CQM::ProportionPopulationMap)
    expect(population_set.populations.IPP.statement_name).to eq('Initial Population')
    expect(population_set.populations.DENOM.statement_name).to eq('Denominator')
    expect(population_set.populations.DENEX.statement_name).to eq('Denominator Exclusions')
    expect(population_set.populations.NUMER.statement_name).to eq('Numerator')
    # check stratifications
    expect(population_set.stratifications.size).to eq(0)
    # check observation
    expect(population_set.observations.size).to eq(0)
    # check SDEs
    expect(population_set.supplemental_data_elements.map(&:statement_name)).to eq(
      [
        'SDE Ethnicity',
        'SDE Payer',
        'SDE Race',
        'SDE Sex'
      ]
    )

    # check composite measure fields
    expect(cqm_measure.composite).to eq(false)
    expect(cqm_measure.component).to eq(true)
    expect(cqm_measure.composite_hqmf_set_id).to eq('244B4F52-C9CA-45AA-8BDB-2F005DA05BFC')
  end
end
