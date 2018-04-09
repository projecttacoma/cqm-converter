require 'spec_helper'

RSpec.describe CQM::Converter do
  before(:all) do
    @converter_classes = CQM::Converter.constants.select do |c|
      CQM::Converter.const_get(c).is_a? Class
    end
  end

  it 'QDMPatient class exists in the converter module' do
    expect(@converter_classes).to include(:QDMPatient)
  end

  it 'HDSRecord class exists in the converter module' do
    expect(@converter_classes).to include(:HDSRecord)
  end
end
