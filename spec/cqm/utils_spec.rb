require 'spec_helper'
require_relative '../../lib/cqm/converter/utils'

RSpec.describe CQM::Converter::Utils do
  it 'date_time_adjuster Preserves Milliseconds' do
    date = { 'year' => 2012, 'month' => 4, 'day' => 6, 'hour' => 8, 'minute' => 3, 'second' => 2, 'millisecond' => 500, 'timezoneOffset' => '-5' }
    adjusted_date = CQM::Converter::Utils.date_time_adjuster(date)
    expect(adjusted_date).to eq('2012-04-06 08:03:02.500000000-05:00')
    date = { 'year' => 2014, 'month' => 9, 'day' => 10, 'hour' => 11, 'minute' => 31, 'second' => 22, 'millisecond' => 999 }
    adjusted_date = CQM::Converter::Utils.date_time_adjuster(date)
    expect(adjusted_date).to eq('2014-09-10 11:31:22.999000000+00:00')
  end
end
