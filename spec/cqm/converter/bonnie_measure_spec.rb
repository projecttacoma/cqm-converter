require 'spec_helper'

RSpec.describe CQM::Converter::BonnieMeasure do

  it 'converts proportion measure with single population set' do
    bonnie_measure = CqlMeasure.new.from_json(File.read('spec/fixtures/bonnie/CMS134v6.json'))
    cqm_measure = CQM::Converter::BonnieMeasure.to_cqm(bonnie_measure)

    expect(cqm_measure).to_not be_nil
    expect(cqm_measure.measure_scoring).to eq('PROPORTION')
    expect(cqm_measure.calculation_method).to eq('PATIENT')

    expect(cqm_measure.cql_libraries.size).to eq(3)

    # check the main library name and find new library structure using it
    expect(cqm_measure.main_cql_library).to eq('DiabetesMedicalAttentionforNephropathy')
    main_library = cqm_measure.cql_libraries.select { |lib| lib.library_name == cqm_measure.main_cql_library }.first

    # check the new library structure
    expect(main_library).to_not be_nil
    expect(main_library.library_name).to eq('DiabetesMedicalAttentionforNephropathy')
    expect(main_library.library_version).to eq('6.1.003')
    expect(main_library.statement_dependencies.size).to eq(18)
    expect(main_library.elm_annotations).to eq(bonnie_measure.elm_annotations['DiabetesMedicalAttentionforNephropathy'])
    expect(main_library.elm).to eq(bonnie_measure.elm[0])
    expect(main_library.cql).to start_with('library DiabetesMedicalAttentionforNephropathy')

    # check the references used by the "Initial Population"
    ipp_dep = main_library.statement_dependencies.select { |dep| dep.statement_name == "Initial Population"}.first
    expect(ipp_dep).to_not be_nil
    expect(ipp_dep.statement_references.size).to eq(3)
    expect(ipp_dep.statement_references.map(&:statement_name)).to include("Qualifying Encounters")

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
    expect(population_set.populations).to be_instance_of(CQM::RatioPopulationMap)
    expect(population_set.populations.IPP.statement_name).to eq("Initial Population")
  end

  it 'converts proportion measure with three population sets' do
    bonnie_measure = CqlMeasure.new.from_json(File.read('spec/fixtures/bonnie/CMS160v6.json'))
    cqm_measure = CQM::Converter::BonnieMeasure.to_cqm(bonnie_measure)

    expect(cqm_measure).to_not be_nil
    expect(cqm_measure.measure_scoring).to eq('PROPORTION')
    expect(cqm_measure.calculation_method).to eq('PATIENT')

    expect(cqm_measure.cql_libraries.size).to eq(1)

    # check the main library name and find new library structure using it
    expect(cqm_measure.main_cql_library).to eq('DepressionUtilizationofthePHQ9Tool')
    main_library = cqm_measure.cql_libraries.select { |lib| lib.library_name == cqm_measure.main_cql_library }.first

    # check the new library structure
    expect(main_library).to_not be_nil
    expect(main_library.library_name).to eq('DepressionUtilizationofthePHQ9Tool')
    expect(main_library.library_version).to eq('6.1.001')
    expect(main_library.statement_dependencies.size).to eq(33)
    expect(main_library.elm_annotations).to eq(bonnie_measure.elm_annotations['DepressionUtilizationofthePHQ9Tool'])
    expect(main_library.elm).to eq(bonnie_measure.elm[0])
    expect(main_library.cql).to start_with('library DepressionUtilizationofthePHQ9Tool')

    # check the references used by the "Initial Population 1"
    ipp_dep = main_library.statement_dependencies.select { |dep| dep.statement_name == "Initial Population 1"}.first
    expect(ipp_dep).to_not be_nil
    expect(ipp_dep.statement_references.size).to eq(3)
    expect(ipp_dep.statement_references.map(&:statement_name)).to include("Depression Face to Face Encounter 1")

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
    expect(population_set.populations).to be_instance_of(CQM::RatioPopulationMap)
    expect(population_set.populations.IPP.statement_name).to eq("Initial Population 1")

    population_set = cqm_measure.population_sets[1]
    expect(population_set.id).to eq('PopulationCriteria2')
    expect(population_set.title).to eq('Population Criteria Section 2')
    expect(population_set.populations).to be_instance_of(CQM::RatioPopulationMap)
    expect(population_set.populations.DENOM.statement_name).to eq("Denominator 2")

    population_set = cqm_measure.population_sets[2]
    expect(population_set.id).to eq('PopulationCriteria3')
    expect(population_set.title).to eq('Population Criteria Section 3')
    expect(population_set.populations).to be_instance_of(CQM::RatioPopulationMap)
    expect(population_set.populations.NUMER.statement_name).to eq("Numerator 3")
  end


  it 'converts continuous variable episode measure with single population set and three stratifications' do
    bonnie_measure = CqlMeasure.new.from_json(File.read('spec/fixtures/bonnie/CMS32v7.json'))
    cqm_measure = CQM::Converter::BonnieMeasure.to_cqm(bonnie_measure)

    expect(cqm_measure).to_not be_nil
    expect(cqm_measure.measure_scoring).to eq('CONTNIUOUS_VARIABLE')
    expect(cqm_measure.calculation_method).to eq('EPISODE')

    expect(cqm_measure.cql_libraries.size).to eq(1)

    # check the main library name and find new library structure using it
    expect(cqm_measure.main_cql_library).to eq('MedianTimefromEDArrivaltoEDDepartureforDischargedEDPatients')
    main_library = cqm_measure.cql_libraries.select { |lib| lib.library_name == cqm_measure.main_cql_library }.first

    # check the new library structure
    expect(main_library).to_not be_nil
    expect(main_library.library_name).to eq('MedianTimefromEDArrivaltoEDDepartureforDischargedEDPatients')
    expect(main_library.library_version).to eq('7.2.002')
    expect(main_library.statement_dependencies.size).to eq(13)
    expect(main_library.elm_annotations).to eq(bonnie_measure.elm_annotations['MedianTimefromEDArrivaltoEDDepartureforDischargedEDPatients'])
    expect(main_library.elm).to eq(bonnie_measure.elm[0])
    expect(main_library.cql).to start_with('library MedianTimefromEDArrivaltoEDDepartureforDischargedEDPatients')

    # check the references used by the "Initial Population"
    ipp_dep = main_library.statement_dependencies.select { |dep| dep.statement_name == "Initial Population"}.first
    expect(ipp_dep).to_not be_nil
    expect(ipp_dep.statement_references.size).to eq(1)
    expect(ipp_dep.statement_references.map(&:statement_name)).to include("ED Visit")

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
    expect(population_set.populations.IPP.statement_name).to eq("Initial Population")
  end
end