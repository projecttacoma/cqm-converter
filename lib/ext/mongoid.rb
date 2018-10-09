module BSON
  # Monkey patch BSON::ObjectId to just return the string for to_json. This is done to match operation in bonnie.
  class ObjectId
    def to_json(*args)
      to_s.to_json
    end

    def as_json(*args)
      to_s.as_json
    end
  end
end
