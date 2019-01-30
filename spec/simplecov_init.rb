require 'simplecov'

SimpleCov.start do
  add_filter 'spec/'
end

class SimpleCov::Formatter::QualityFormatter
  def format(result)
    SimpleCov::Formatter::HTMLFormatter.new.format(result)
    File.open('coverage/covered_percent', 'w') do |f|
      f.puts result.source_files.covered_percent.to_f
    end
  end
end

if ENV['CI'] == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
else
  SimpleCov.formatter = SimpleCov::Formatter::QualityFormatter
end
