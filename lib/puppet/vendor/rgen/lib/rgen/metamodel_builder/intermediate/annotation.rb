module RGen

module MetamodelBuilder

module Intermediate

class Annotation
  attr_reader :details, :source
  
  def initialize(hash)
    if hash[:source] || hash[:details]
      restKeys = hash.keys - [:source, :details]
      raise "Hash key #{restKeys.first} not allowed." unless restKeys.empty?
      raise "Details not provided, key :details is missing" unless hash[:details]
      raise "Details must be provided as a hash" unless hash[:details].is_a?(Hash)
      @details = hash[:details]
      @source = hash[:source]
    else
      raise "Details must be provided as a hash" unless hash.is_a?(Hash)
      @details = hash
    end
  end
  
end

end

end

end
