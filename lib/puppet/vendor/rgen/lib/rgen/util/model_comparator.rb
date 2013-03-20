require 'rgen/ecore/ecore'

module RGen

module Util

module ModelComparator

# This method compares to models regarding equality
# For this the identity of a model element is defined based on identity
# of all attributes and referenced elements.
# Arrays are sorted before comparison if possible (if <=> is provided).
# 
def modelEqual?(a, b, featureIgnoreList=[])
  @modelEqual_visited = {}
  _modelEqual_internal(a, b, featureIgnoreList, [])
end
  
def _modelEqual_internal(a, b, featureIgnoreList, path)
  return true if @modelEqual_visited[[a,b]]
  @modelEqual_visited[[a,b]] = true
  return true if a.nil? && b.nil?
  unless a.class == b.class
    puts "#{path.inspect}\n  Classes differ: #{a} vs. #{b}"
    return false 
  end
  if a.is_a?(Array)
    unless a.size == b.size
      puts "#{path.inspect}\n  Array size differs: #{a.size} vs. #{b.size}"
      return false 
    end
    begin
      # in Ruby 1.9 every object has the <=> operator but the default one returns
      # nil and thus sorting won't work (ArgumentError)
      as = a.sort
    rescue ArgumentError, NoMethodError
      as = a
    end
    begin
      bs = b.sort
    rescue ArgumentError, NoMethodError
      bs = b
    end
    a.each_index do |i|
      return false unless _modelEqual_internal(as[i], bs[i], featureIgnoreList, path+[i])
    end
  else
    a.class.ecore.eAllStructuralFeatures.reject{|f| f.derived}.each do |feat|
      next if featureIgnoreList.include?(feat.name)
      if feat.eType.is_a?(RGen::ECore::EDataType)
        unless a.getGeneric(feat.name) == b.getGeneric(feat.name)
          puts "#{path.inspect}\n  Value '#{feat.name}' differs: #{a.getGeneric(feat.name)} vs. #{b.getGeneric(feat.name)}"
          return false
        end
      else
        return false unless _modelEqual_internal(a.getGeneric(feat.name), b.getGeneric(feat.name), featureIgnoreList, path+["#{a.respond_to?(:name) && a.name}:#{feat.name}"])
      end
    end
  end
  return true
end

end

end

end
 
