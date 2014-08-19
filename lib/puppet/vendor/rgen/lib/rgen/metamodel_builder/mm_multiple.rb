
module RGen

module MetamodelBuilder

def self.MMMultiple(*superclasses)
  c = Class.new(MMBase)
  class << c
    attr_reader :multiple_superclasses
  end
  c.instance_variable_set(:@multiple_superclasses, superclasses)
  superclasses.collect{|sc| sc.ancestors}.flatten.
    reject{|m| m.is_a?(Class)}.each do |arg|
      c.instance_eval do
        include arg
      end
  end
  return c
end

end

end