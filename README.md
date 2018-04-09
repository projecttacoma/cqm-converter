# HDS <=> QDM Models Converter

This repository includes a Ruby Gem that provides a module for converting between the older HDS based models (https://github.com/projectcypress/health-data-standards) and the newer QDM based models (https://github.com/projecttacoma/cqm-models).

## HDS Record => QDM Patient

The `CQM::Converter` module provides a class (`CQM::Converter::HDSRecord`) for converting an HDS based patient `Record` into a QDM based `Patient`.

### Programmatic Conversion

Example:
```
require 'cqm/converter'

# Initialize a new HDS converter. NOTE: This only needs to be done once, and
# should be re-used for every patient you wish to convert!
hds_record_converter = CQM::Converter::HDSRecord.new

# Read in an HDS record JSON file and create an HDS record object from it.
hds_record = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/1.json')))

# Convert the HDS record into a QDM Patient.
qdm_patient = hds_record_converter.to_qdm(hds_record)
```

### Rake Task Conversion

Also included is a rake task to do this conversion. Just point it to a JSON file containing an HDS `Record`, and it will output the corresponding QDM `Patient` JSON to STDOUT.

__Note__: This rake task is not intended for anything other than experimentation. Any serious use of this library should be programmatic.

Example:
```
bundle exec rake cqm:hds:to_qdm RECORD=spec/fixtures/hds/records/eh/1.json
```

## HDS Record <= QDM Patient

TODO
