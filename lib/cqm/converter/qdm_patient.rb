# CQM Converter module for QDM models.
module CQM::Converter
  # CQM Converter class for QDM based patients.
  class QDMPatient
    # Given a QDM patient, return a corresponding HDS record.
    def self.to_hds(patient)
      raise 'Unimplemented!' + patient
    end
  end
end
