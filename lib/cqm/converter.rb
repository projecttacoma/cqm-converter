require 'active_support/inflector'
require 'health-data-standards'
require 'cqm/models'

# Base CQM module.
module CQM
  # Base CQM Converter module.
  module Converter
  end
end

require_relative '../ext/mongoid'
require_relative 'converter/utils'
require_relative 'converter/hds_record'
require_relative 'converter/qdm_patient'
