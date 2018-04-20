# HDS <=> QDM Models Converter

This repository includes a Ruby Gem that provides a module for converting between the older HDS based models (https://github.com/projectcypress/health-data-standards) and the newer QDM based models (https://github.com/projecttacoma/cqm-models).

See the `Gemfile` for specific Gem dependency requirements for using this library.

## Installation

Include cqm-converter in your Gemfile:
```
gem 'cqm-converter'
```

Then run `bundle install`.

## HDS Record => QDM Patient

The `CQM::Converter` module provides a class (`CQM::Converter::HDSRecord`) for converting an HDS `Record` into a QDM `Patient`.

### Programmatic Conversion

Example:
```
require 'cqm/converter'

# Initialize a new HDS converter. NOTE: This only needs to be done once, and
# should be re-used for every patient you wish to convert!
hds_record_converter = CQM::Converter::HDSRecord.new

# Read in an HDS record JSON file and create an HDS Record object from it.
hds_record = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/1.json')))

# Convert the HDS Record into a QDM Patient.
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

The `CQM::Converter` module provides a class (`CQM::Converter::QDMPatient`) for converting a QDM `Patient` into an HDS `Record`.

### Programmatic Conversion

Example:
```
require 'cqm/converter'

# Initialize a new QDM converter. NOTE: This only needs to be done once, and
# should be re-used for every patient you wish to convert!
qdm_patient_converter = CQM::Converter::QDMPatient.new

# Read in a QDM patient JSON file and create a QDM Patient object from it.
qdm_patient = QDM::Patient.new.from_json(File.read('spec/fixtures/qdm/patients/eh/1.json')))

# Convert the QDM Patient into a HDS Record.
hds_record = qdm_patient_converter.to_hds(qdm_patient)
```

### Rake Task Conversion

Also included is a rake task to do this conversion. Just point it to a JSON file containing a QDM `Patient`, and it will output the corresponding HDS `Record` JSON to STDOUT.

__Note__: This rake task is not intended for anything other than experimentation. Any serious use of this library should be programmatic.

Example:
```
bundle exec rake cqm:qdm:to_hds RECORD=spec/fixtures/qdm/patients/eh/1.json
```
