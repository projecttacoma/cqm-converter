# placeholder class needed for bonnie measure model
class User
  include Mongoid::Document
end

namespace :cqm do
  namespace :bonnie do
    def dump_db
      Mongoid.load!('config/mongoid.yml', :test)
      Mongo::Logger.logger.level = Logger::FATAL
      Mongoid.client(:default).database.drop
    end

    desc %(Convert a bonnie measure, represented as a JSON file, into a CQM measure, represented as JSON.

    You must specify an input bonnie measure JSON file. The result will be
    output to STDOUT unless an output file is specified.

    Value sets can also be converted by pointing to a JSON file with the HDS value sets in an array. There are three forms that the
    value sets fixtures are allowed to be in.
      - An array of value set objects.
      - A map of OIDs to value set objects.
      - A map of OIDs to versions to value set objects.

    $ rake cqm:bonnie:to_cqm MEASURE=spec/fixtures/bonnie/CMS999v9.json VALUESETS=spec/fixtures/hds/valuesets/CMS999v9.json\
      MEASURE_OUT=spec/fixtures/cqm/measure/CMS999v9.json VALUESETS_OUT=spec/fixutres/cqm/valuesets/CMS999v9.json)
    task :to_cqm do
      dump_db
      # load bonnie measure
      bonnie_measure = CqlMeasure.new.from_json(File.read(ENV['MEASURE']))
      bonnie_measure.save

      # load HDS valuesets if they are provided
      if ENV.key?('VALUESETS')
        value_set_fixtures = JSON.parse(File.read(ENV['VALUESETS']))
        # if the fixture file is an array then simply load each element in as a valueset.
        if value_set_fixtures.is_a?(Array)
          hds_value_sets = value_set_fixtures.map do |vs_json|
            HealthDataStandards::SVS::ValueSet.new(vs_json)
          end
        else
          hds_value_sets = []
          # if the fixture file is an object. then we should iterate over the pairs
          value_set_fixtures.each_pair do |_, versions|
            # if there is a _id then this level is a actually a valueset fixture and the file is a map of OIDs to valuesets
            if versions.key?('_id')
              hds_value_sets << HealthDataStandards::SVS::ValueSet.new(versions)
            else
              # if we have to go down another level then this file is a map of OIDs to versions to value sets
              versions.each_pair do |_, vs_json|
                hds_value_sets << HealthDataStandards::SVS::ValueSet.new(vs_json)
              end
            end
          end
        end
        hds_value_sets.each(&:save)
      end

      # convert measure and valuesets if they exist
      cqm_measure = CQM::Converter::BonnieMeasure.to_cqm(bonnie_measure)
      pretty_measure_json = JSON.pretty_generate(JSON.parse(cqm_measure.to_json(except: '_id', methods: :_type)))

      # if output location is provided write to file, otherwise to STDOUT
      if ENV.key?('MEASURE_OUT')
        File.write(ENV['MEASURE_OUT'], pretty_measure_json)
      else
        puts pretty_measure_json
      end

      # if value set output is defined, export if there are valuesets
      if ENV.key?('VALUESETS_OUT') && !cqm_measure.value_sets.empty?
        File.write(ENV['VALUESETS_OUT'], JSON.pretty_generate(JSON.parse(cqm_measure.value_sets.to_json)))
      end
    end
  end
end
