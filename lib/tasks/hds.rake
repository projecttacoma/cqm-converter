namespace :cqm do
  namespace :hds do
    desc %(Convert an HDS Record, represented as a JSON file, into a CQM
    Patient, represented as JSON.

    You must specify an input HDS Record JSON file. The result will be
    output to STDOUT.

    $ rake cqm:hds:to_cqm RECORD=spec/fixtures/hds/records/ep/1.json)
    task :to_cqm do
      converter = CQM::Converter::HDSRecord.new
      record = Record.new.from_json(File.read(ENV['RECORD']))
      puts JSON.pretty_generate(JSON.parse(converter.to_cqm(record).to_json(except: '_id')))
    end
  end
end
