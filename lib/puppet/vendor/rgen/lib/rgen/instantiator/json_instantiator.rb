require 'rgen/instantiator/qualified_name_resolver'
require 'rgen/instantiator/json_parser'

module RGen

module Instantiator

# JsonInstantiator is used to create RGen models from JSON.
#
# Each JSON object needs to have an attribute "_class" which is used to find
# the metamodel class to instantiate. The value of "_class" should be the 
# the relative qualified class name within the root package as a string. 
#
# If the option "short_class_names" is set to true, unqualified class names can be used.
# In this case, metamodel classes are searched in the metamodel root package first.
# If this search is not successful, all subpackages will be searched for the class name.
#
class JsonInstantiator

  # Model elements will be created in evironment +env+,
  # classes are looked for in metamodel package module +mm+,
  # +options+ include:
  #   short_class_names: if true subpackages will be searched for unqualifed class names (default: true)
  #   ignore_keys:       an array of json object key names which are to be ignored (default: none)
  #
  # The options are also passed to the underlying QualifiedNameResolver.
  #
  def initialize(env, mm, options={})
    @env = env
    @mm = mm
    @options = options
    @short_class_names = !@options.has_key?(:short_class_names) || @options[:short_class_names]
    @ignore_keys = @options[:ignore_keys] || []
    @unresolvedReferences = []
    @classes = {}
    @classes_flat = {}
    mm.ecore.eAllClasses.each do |c|
      @classes[c.instanceClass.name.sub(mm.name+"::","")] = c
      @classes_flat[c.name] = c
    end
    @parser = JsonParser.new(self)
  end

  # Creates the elements described by the json string +str+.
  # Returns an array of ReferenceResolver::UnresolvedReference
  # describing the references which could not be resolved
  #
  # Options:
  #   :root_elements: if an array is provided, it will be filled with the root elements
  #
  def instantiate(str, options={})
    root = @parser.parse(str)
    if options[:root_elements].is_a?(Array)
      options[:root_elements].clear
      root.each{|r| options[:root_elements] << r}
    end
    resolver = QualifiedNameResolver.new(root, @options)
    resolver.resolveReferences(@unresolvedReferences)
  end

  def createObject(hash)
    className = hash["_class"]
    # hashes without a _class key are returned as is
    return hash unless className
    if @classes[className]
      clazz = @classes[className].instanceClass
    elsif @short_class_names && @classes_flat[className]
      clazz = @classes_flat[className].instanceClass
    else 
      raise "class not found: #{className}"
    end
    hash.delete("_class")
    @ignore_keys.each do |k|
      hash.delete(k)
    end
    urefs = []
    hash.keys.each do |k|
      f = eFeature(k, clazz)
      hash[k] = [hash[k]] if f.many && !hash[k].is_a?(Array)
      if f.is_a?(RGen::ECore::EReference) && !f.containment
        if f.many
          idents = hash[k]
          hash[k] = idents.collect do |i|
            proxy = RGen::MetamodelBuilder::MMProxy.new(i)
            urefs << ReferenceResolver::UnresolvedReference.new(nil, k, proxy)
            proxy
          end
        else
          ident = hash[k]
          ident = ident.first if ident.is_a?(Array)
          proxy = RGen::MetamodelBuilder::MMProxy.new(ident)
          hash[k] = proxy
          urefs << ReferenceResolver::UnresolvedReference.new(nil, k, proxy)
        end
      elsif f.eType.is_a?(RGen::ECore::EEnum)
        hash[k] = hash[k].to_sym
      elsif f.eType.instanceClassName == "Float"
        hash[k] = hash[k].to_f
      end
    end  
    obj = @env.new(clazz, hash)
    urefs.each do |r|
      r.element = obj
      @unresolvedReferences << r 
    end
    obj
  end

  private
  
  def eFeature(name, clazz) 
    @eFeature ||= {}
    @eFeature[clazz] ||= {}
    unless @eFeature[clazz][name] 
      feature = clazz.ecore.eAllStructuralFeatures.find{|f| f.name == name}
      raise "feature '#{name}' not found in class '#{clazz}'" unless feature
    end
    @eFeature[clazz][name] ||= feature
  end
  
end

end

end

