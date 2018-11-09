require 'spec_helper'

RSpec.describe CQM::Converter::BonnieMeasure do

  it 'converts proportion measure with single population set' do
    bonnie_measure = CqlMeasure.new.from_json(File.read('spec/fixtures/bonnie/cms134v6.json'))
    cqm_measure = CQM::Converter::BonnieMeasure.to_cqm(bonnie_measure)

    expect(cqm_measure).to_not be_nil
    expect(cqm_measure.measure_scoring).to eq('PROPORTION')
    expect(cqm_measure.calculation_method).to eq('PATIENT')

    expect(cqm_measure.cql_libraries.size).to eq(3)

    require 'pry'; binding.pry
    main_library = cqm_measure.cql_libraries.select { |lib| lib.library_name == 'DiabetesMedicalAttentionforNephropathy' }.first

    expect(main_library).to_not be_nil
    expect(main_library.library_name).to eq('DiabetesMedicalAttentionforNephropathy')
    expect(main_library.library_version).to eq('6.1.003')
    expect(main_library.statement_dependencies.size).to eq(18)
    expect(main_library)

  end

end