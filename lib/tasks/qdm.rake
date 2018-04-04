namespace :cqm do
  namespace :qdm do
    desc %(Convert a QDM Patient, represented as a JSON file, into an HDS
    Record, represented as JSON.

    You must specify an input QDM Patient JSON file. The result will be
    output to STDOUT.

    $ rake cqm:qdm:to_hds RECORD=spec/fixtures/qdm/patients/ep/1.json)
    task :to_hds do
      converter = CQM::Converter::QDMPatient.new
      patient = QDM::Patient.new.from_json(File.read(ENV['RECORD']))
      puts JSON.pretty_generate(JSON.parse(converter.to_hds(patient).to_json(except: '_id')))
    end
  end
end
