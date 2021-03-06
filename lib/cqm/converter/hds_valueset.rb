# CQM Converter module for HDS/Bonnie models.
module CQM::Converter
  # CQM Converter class for HDS ValueSets.
  module HDSValueSet
    def self.to_cqm(hds_value_set)
      CQM::ValueSet.new(
        oid: hds_value_set.oid,
        display_name: hds_value_set.display_name,
        version: hds_value_set.version,
        concepts: hds_value_set.concepts.map do |hds_concept|
          CQM::Concept.new(
            code: hds_concept.code,
            code_system_name: hds_concept.code_system_name,
            code_system_version: hds_concept.code_system_version,
            code_system_oid: HealthDataStandards::Util::CodeSystemHelper.oid_for_code_system(hds_concept.code_system_name),
            display_name: hds_concept.display_name
          )
        end
      )
    end

    def self.list_to_cqm(hds_value_sets, value_set_oid_version_objects)
      value_set_versions = {}
      value_sets = []
      value_set_oid_version_objects.each do |vs|
        if vs['version'] == 'N/A'
          vs['version'] = ''
        end
        value_set_versions[vs['oid']] = vs['version']
      end
      hds_value_sets.each do |hds_value_set|
        if hds_value_set.version == value_set_versions[hds_value_set.oid] || value_set_versions[hds_value_set.oid] == ''
          value_sets.push(to_cqm(hds_value_set))
        end
      end
      value_sets
    end
  end
end
