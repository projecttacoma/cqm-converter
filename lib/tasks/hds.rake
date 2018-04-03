namespace :cqm do
  namespace :hds do
    desc %(Convert an HDS record, represented as a JSON file, into a QDM
    patient, represented as JSON.

    You must specify an input HDS record JSON file. The result will be
    output to STDOUT.

    $ rake cqm:hds:to_qdm RECORD=record.json)
    task :to_qdm do
      converter = CQM::Converter::HDSRecord.new
      record = Record.new.from_json(File.read(ENV['RECORD']))
      puts JSON.pretty_generate(JSON.parse(converter.to_qdm(record).to_json(except: [:_id])))
    end
  end
end
