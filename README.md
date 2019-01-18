[![Build Status](https://travis-ci.org/projecttacoma/cqm-converter.svg?branch=master)](https://travis-ci.org/projecttacoma/cqm-converter)

# HDS <=> CQM Models Converter

This repository includes a Ruby Gem that provides a module for converting between the older HDS based models (https://github.com/projectcypress/health-data-standards) and the newer CQM based models (https://github.com/projecttacoma/cqm-models).

See the `Gemfile` for specific Gem dependency requirements for using this library.

## Installation

Include cqm-converter in your Gemfile:
```
gem 'cqm-converter'
```

Then run `bundle install`.

## HDS Record => CQM Patient

The `CQM::Converter` module provides a class (`CQM::Converter::HDSRecord`) for converting an HDS `Record` into a CQM `Patient`.

### Programmatic Conversion

Example:
```ruby
require 'cqm/converter'

# Initialize a new HDS converter. NOTE: This only needs to be done once, and
# should be re-used for every patient you wish to convert!
hds_record_converter = CQM::Converter::HDSRecord.new

# Read in an HDS record JSON file and create an HDS Record object from it.
hds_record = Record.new.from_json(File.read('spec/fixtures/hds/records/eh/1.json')))

# Convert the HDS Record into a CQM Patient.
cqm_patient = hds_record_converter.to_cqm(hds_record)
```

### Rake Task Conversion

Also included is a rake task to do this conversion. Just point it to a JSON file containing an HDS `Record`, and it will output the corresponding CQM `Patient` JSON to STDOUT.

__Note__: This rake task is not intended for anything other than experimentation. Any serious use of this library should be programmatic.

Example:
```
bundle exec rake cqm:hds:to_cqm RECORD=spec/fixtures/hds/records/eh/1.json
```

## License

Copyright 2018 The MITRE Corporation

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

```
http://www.apache.org/licenses/LICENSE-2.0
```

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.