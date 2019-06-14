require 'spec_helper'
require 'pry'
def check_source_data_criteria_converted_correctly(bonnie_measure, cqm_measure)
  # check source data criteria
  code_list_ids = []
  descriptions = []
  # SDC with duplicate code_list_id and descriptions are removed since the newly converted CQM measure shouldn't have duplicates
  unique_sdc = bonnie_measure.source_data_criteria.values.index_by { |sdc| [sdc['code_list_id'], sdc['description']] }
  unique_sdc.map do |_, sdc|
    code_list_ids << sdc['code_list_id']
    descriptions << sdc['description']
  end
  expect(cqm_measure.source_data_criteria.length).to eq(unique_sdc.count)
  expect(cqm_measure.source_data_criteria.map(&:description)).to eq(descriptions)
  expect(cqm_measure.source_data_criteria.map(&:codeListId)).to eq(code_list_ids)
  expect(cqm_measure.source_data_criteria.map { |sdc| sdc.class.ancestors[2] }.uniq).to eq([QDM::DataElement])
end

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
    expect(cqm_measure.measure_period).to eq(bonnie_measure.measure_period)
    expect(cqm_measure.measure_attributes).to eq(bonnie_measure.measure_attributes)

    # check population set
    expect(cqm_measure.population_sets.size).to eq(1)
    population_set = cqm_measure.population_sets[0]
    expect(population_set.population_set_id).to eq('PopulationCriteria1')
    expect(population_set.title).to eq('Population Criteria Section')
    expect((population_set.populations.instance_of? CQM::ProportionPopulationMap)).to eq(true)
    expect(population_set.populations.IPP.statement_name).to eq('Initial Population')
    expect(population_set.populations.IPP.hqmf_id).to eq('6CD39B4B-16E6-4FD4-9241-527F9F4A48D0')
    expect(population_set.populations.DENOM.statement_name).to eq('Denominator')
    expect(population_set.populations.DENOM.hqmf_id).to eq('B735F4BD-DFAE-45E3-BAA9-E09BDF731B8E')

    check_source_data_criteria_converted_correctly(bonnie_measure, cqm_measure)
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
    # Assert code system id's have been changed from name to oid
    expect(main_library.elm['library']['codeSystems']['def'][0]['id']).to eq("2.16.840.1.113883.6.96")
    expect(main_library.cql).to start_with('library DepressionUtilizationofthePHQ9Tool')
    expect(main_library.is_main_library).to eq(true)

    # check the references used by the "Initial Population 1"
    ipp_dep = main_library.statement_dependencies.select { |dep| dep.statement_name == 'Initial Population 1' }.first
    expect(ipp_dep).to_not be_nil
    expect(ipp_dep.statement_references.size).to eq(3)
    expect(ipp_dep.statement_references.map(&:statement_name)).to include('Depression Face to Face Encounter 1')

    # Legacy fields that may be removed later
    expect(cqm_measure.population_criteria).to eq(bonnie_measure.population_criteria)
    expect(cqm_measure.measure_period).to eq(bonnie_measure.measure_period)
    expect(cqm_measure.measure_attributes).to eq(bonnie_measure.measure_attributes)

    # check population set 1
    expect(cqm_measure.population_sets.size).to eq(3)
    population_set = cqm_measure.population_sets[0]
    expect(population_set.population_set_id).to eq('PopulationCriteria1')
    expect(population_set.title).to eq('Population Criteria Section 1')
    expect((population_set.populations.instance_of? CQM::ProportionPopulationMap)).to eq(true)
    expect(population_set.populations.IPP.statement_name).to eq('Initial Population 1')
    expect(population_set.populations.IPP.hqmf_id).to eq('E5CAD3E0-2CF4-4F7D-B0CB-84CEA6BC44AB')
    expect(population_set.populations.DENEX.statement_name).to eq('Denominator Exclusion 1')
    expect(population_set.populations.DENEX.hqmf_id).to eq('08821615-9B0E-4C1C-AE75-63807597A68E')

    population_set = cqm_measure.population_sets[1]
    expect(population_set.population_set_id).to eq('PopulationCriteria2')
    expect(population_set.title).to eq('Population Criteria Section 2')
    expect((population_set.populations.instance_of? CQM::ProportionPopulationMap)).to eq(true)
    expect(population_set.populations.IPP.statement_name).to eq('Initial Population 2')
    expect(population_set.populations.IPP.hqmf_id).to eq('6D6BC9D7-1492-412C-A076-EC0A6DFEFC4C')
    expect(population_set.populations.DENOM.statement_name).to eq('Denominator 2')
    expect(population_set.populations.DENOM.hqmf_id).to eq('70D8CAA3-4182-41C0-9A73-335396BB6764')

    population_set = cqm_measure.population_sets[2]
    expect(population_set.population_set_id).to eq('PopulationCriteria3')
    expect(population_set.title).to eq('Population Criteria Section 3')
    expect((population_set.populations.instance_of? CQM::ProportionPopulationMap)).to eq(true)
    expect(population_set.populations.DENOM.statement_name).to eq('Denominator 3')
    expect(population_set.populations.DENOM.hqmf_id).to eq('1EE7E1F6-E10A-4BE0-93C5-EED14D088023')
    expect(population_set.populations.NUMER.statement_name).to eq('Numerator 3')
    expect(population_set.populations.NUMER.hqmf_id).to eq('4C5B11DD-040D-460D-B6F6-57D440BE7B36')

    check_source_data_criteria_converted_correctly(bonnie_measure, cqm_measure)
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
    expect(cqm_measure.value_sets.size).to eq(bonnie_measure.value_set_oid_version_objects.size)
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
    main_library.elm['library']['codeSystems'] = {}
    bonnie_measure.elm[0]['library']['codeSystems'] = {}
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
    expect(cqm_measure.measure_period).to eq(bonnie_measure.measure_period)
    expect(cqm_measure.measure_attributes).to eq(bonnie_measure.measure_attributes)

    # check population set
    expect(cqm_measure.population_sets.size).to eq(1)
    population_set = cqm_measure.population_sets[0]
    expect(population_set.population_set_id).to eq('PopulationCriteria1')
    expect(population_set.title).to eq('Population Criteria Section')
    expect((population_set.populations.instance_of? CQM::ContinuousVariablePopulationMap)).to eq(true)
    expect(population_set.populations.IPP.statement_name).to eq('Initial Population')
    expect(population_set.populations.IPP.hqmf_id).to eq('036B7EEE-DEB5-40E2-B802-BC6CDF2B8A43')
    expect(population_set.populations.MSRPOPL.statement_name).to eq('Measure Population')
    expect(population_set.populations.MSRPOPL.hqmf_id).to eq('4A80FF43-6FC1-4975-806B-4FD40C7C4B95')
    expect(population_set.populations.MSRPOPLEX.statement_name).to eq('Measure Population Exclusions')
    expect(population_set.populations.MSRPOPLEX.hqmf_id).to eq('34607208-5E04-4BC6-94E4-F3168609640E')
    # check stratifications
    expect(population_set.stratifications.size).to eq(3)
    expect(population_set.stratifications[0].stratification_id).to eq('PopulationCriteria1 - Stratification 1')
    expect(population_set.stratifications[0].title).to eq('Stratification 1')
    expect(population_set.stratifications[0].hqmf_id).to eq('041A37F6-86D3-471F-86DD-12FB668092BD')
    expect(population_set.stratifications[0].statement.statement_name).to eq('Stratification 1')
    expect(population_set.stratifications[0].statement.hqmf_id).to eq('041A37F6-86D3-471F-86DD-12FB668092BD')
    expect(population_set.stratifications[1].stratification_id).to eq('PopulationCriteria1 - Stratification 2')
    expect(population_set.stratifications[1].title).to eq('Stratification 2')
    expect(population_set.stratifications[1].hqmf_id).to eq('7846CD9A-9B68-4C2C-9CFB-0E52777D9EEA')
    expect(population_set.stratifications[1].statement.statement_name).to eq('Stratification 2')
    expect(population_set.stratifications[1].statement.hqmf_id).to eq('7846CD9A-9B68-4C2C-9CFB-0E52777D9EEA')
    expect(population_set.stratifications[2].stratification_id).to eq('PopulationCriteria1 - Stratification 3')
    expect(population_set.stratifications[2].title).to eq('Stratification 3')
    expect(population_set.stratifications[2].hqmf_id).to eq('566164F8-47E0-4ADB-A3A6-383067490DA8')
    expect(population_set.stratifications[2].statement.statement_name).to eq('Stratification 3')
    expect(population_set.stratifications[2].statement.hqmf_id).to eq('566164F8-47E0-4ADB-A3A6-383067490DA8')
    # check observation
    expect(population_set.observations.size).to eq(1)
    expect(population_set.observations[0].observation_function.statement_name).to eq('Measure Observation')
    expect(population_set.observations[0].observation_function.hqmf_id).to eq('FFB1B6BE-B96F-4B29-A920-0E4966D209A3')
    expect(population_set.observations[0].observation_parameter.statement_name).to eq('Measure Population')
    expect(population_set.observations[0].observation_parameter.hqmf_id).to eq('FFB1B6BE-B96F-4B29-A920-0E4966D209A3')
    expect(population_set.observations[0].hqmf_id).to eq('FFB1B6BE-B96F-4B29-A920-0E4966D209A3')
    # check valuesets
    expect(cqm_measure.value_sets.size).to eq(bonnie_measure.value_set_oid_version_objects.size)

    check_source_data_criteria_converted_correctly(bonnie_measure, cqm_measure)
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
    expect(cqm_measure.measure_period).to eq(bonnie_measure.measure_period)
    expect(cqm_measure.measure_attributes).to eq(bonnie_measure.measure_attributes)

    # check population set
    expect(cqm_measure.population_sets.size).to eq(1)
    population_set = cqm_measure.population_sets[0]
    expect(population_set.population_set_id).to eq('PopulationCriteria1')
    expect(population_set.title).to eq('Population Criteria Section')
    expect((population_set.populations.instance_of? CQM::ProportionPopulationMap)).to eq(true)
    expect(population_set.populations.IPP.statement_name).to eq('Initial Population')
    expect(population_set.populations.IPP.hqmf_id).to eq('814DC710-4366-4E53-8747-EA68A1D82146')
    expect(population_set.populations.DENOM.statement_name).to eq('Denominator')
    expect(population_set.populations.DENOM.hqmf_id).to eq('FB9470CF-9D17-4D21-A56C-DD50333C41DB')
    expect(population_set.populations.DENEX).to be_nil
    expect(population_set.populations.NUMER.statement_name).to eq('Numerator')
    expect(population_set.populations.NUMER.hqmf_id).to eq('487BEADB-29B5-43D7-8E33-F0E40184E27B')
    # check stratifications
    expect(population_set.stratifications.size).to eq(0)
    # check observation
    expect(population_set.observations.size).to eq(0)
    # check SDEs
    expect(population_set.supplemental_data_elements.size).to eq(0)

    check_source_data_criteria_converted_correctly(bonnie_measure, cqm_measure)
  end

  it 'converts composite measure' do
    bonnie_measure = CqlMeasure.new.from_json(File.read('spec/fixtures/bonnie/AWA_composite.json'))
    cqm_measure = CQM::Converter::BonnieMeasure.to_cqm(bonnie_measure)

    expect(cqm_measure).to_not be_nil
    expect(cqm_measure.measure_scoring).to eq('CONTINUOUS_VARIABLE')
    expect(cqm_measure.calculation_method).to eq('PATIENT')

    # duplicate libraries should be removed
    expect(cqm_measure.cql_libraries.size).to eq(11)
    expect(cqm_measure.cql_libraries.select(&:is_main_library).size).to eq(1)
    expect(cqm_measure.cql_libraries.reject(&:is_main_library).size).to eq(10)

    # library order should match order of cql_statement_dependencies
    expect(cqm_measure.cql_libraries.collect(&:library_name)).to eq(bonnie_measure.cql_statement_dependencies.keys)

    # check the main library name and find new library structure using it
    expect(cqm_measure.main_cql_library).to eq('AWATestComposite')
    expect(cqm_measure.cql_libraries.find_by(library_name: 'AWATestComposite').is_top_level).to eq(true)
    expect(cqm_measure.cql_libraries.find_by(library_name: 'MATGlobalCommonFunctions').is_top_level).to eq(false)

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
    expect(cqm_measure.measure_period).to eq(bonnie_measure.measure_period)
    expect(cqm_measure.measure_attributes).to eq(bonnie_measure.measure_attributes)

    # check population set
    expect(cqm_measure.population_sets.size).to eq(1)
    population_set = cqm_measure.population_sets[0]
    expect(population_set.population_set_id).to eq('PopulationCriteria1')
    expect(population_set.title).to eq('Population Criteria Section')
    expect((population_set.populations.instance_of? CQM::ContinuousVariablePopulationMap)).to eq(true)
    expect(population_set.populations.IPP.statement_name).to eq('Initial Population')
    expect(population_set.populations.IPP.hqmf_id).to eq('136D71C8-8541-45DA-8486-4279A21078F4')
    expect(population_set.populations.MSRPOPL.statement_name).to eq('Measure Population')
    expect(population_set.populations.MSRPOPL.hqmf_id).to eq('64F43997-E94E-4FAF-BEE9-EB6758F380C5')
    expect(population_set.populations.MSRPOPLEX.statement_name).to eq('Measure Population Exclusions')
    expect(population_set.populations.MSRPOPLEX.hqmf_id).to eq('07F38F88-9008-4436-AC4A-C9ABA6FA5F95')
    # check stratifications
    expect(population_set.stratifications.size).to eq(0)
    # check observation
    expect(population_set.observations.size).to eq(1)
    expect(population_set.observations[0].observation_function.statement_name).to eq('Measure Observation')
    expect(population_set.observations[0].observation_function.hqmf_id).to eq('BB3FA997-D7F6-4872-A004-9484EF913C7F')
    expect(population_set.observations[0].observation_parameter.statement_name).to eq('Measure Population')
    expect(population_set.observations[0].observation_parameter.hqmf_id).to eq('BB3FA997-D7F6-4872-A004-9484EF913C7F')
    expect(population_set.observations[0].hqmf_id).to eq('BB3FA997-D7F6-4872-A004-9484EF913C7F')
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

    check_source_data_criteria_converted_correctly(bonnie_measure, cqm_measure)
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
    # Assert code system id's have been changed from name to oid
    expect(main_library.elm['library']['codeSystems']['def'][0]['id']).to eq("2.16.840.1.113883.6.1")
    expect(main_library.elm['library']['codeSystems']['def'][1]['id']).to eq("2.16.840.1.113883.6.96")
    main_library.elm['library']['codeSystems'] = {}
    bonnie_measure.elm[0]['library']['codeSystems'] = {}
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
    expect(cqm_measure.measure_period).to eq(bonnie_measure.measure_period)
    expect(cqm_measure.measure_attributes).to eq(bonnie_measure.measure_attributes)

    # check population set
    expect(cqm_measure.population_sets.size).to eq(1)
    population_set = cqm_measure.population_sets[0]
    expect(population_set.population_set_id).to eq('PopulationCriteria1')
    expect(population_set.title).to eq('Population Criteria Section')
    expect((population_set.populations.instance_of? CQM::ProportionPopulationMap)).to eq(true)
    expect(population_set.populations.IPP.statement_name).to eq('Initial Population')
    expect(population_set.populations.IPP.hqmf_id).to eq('8DF5C762-DA90-4D43-BCD2-F266F6E75F83')
    expect(population_set.populations.DENOM.statement_name).to eq('Denominator')
    expect(population_set.populations.DENOM.hqmf_id).to eq('D8E4FFD1-8B7B-4B3F-A9A3-9BF8DC51E529')
    expect(population_set.populations.DENEX.statement_name).to eq('Denominator Exclusions')
    expect(population_set.populations.DENEX.hqmf_id).to eq('B6D5424F-E911-4688-9759-5BC7FCEBCA2E')
    expect(population_set.populations.NUMER.statement_name).to eq('Numerator')
    expect(population_set.populations.NUMER.hqmf_id).to eq('2B35FE50-8557-4415-9AC5-5F32225C427E')
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

    check_source_data_criteria_converted_correctly(bonnie_measure, cqm_measure)
  end
end
