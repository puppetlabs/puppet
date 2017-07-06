require 'rgen/ecore/ecore'
require 'rgen/instantiator/abstract_xml_instantiator'
require 'rgen/array_extensions'

class XMI11Instantiator < AbstractXMLInstantiator
  
  include RGen::ECore

  ResolverDescription = Struct.new(:object, :attribute, :value, :many)
  
  INFO = 0
  WARN = 1
  ERROR = 2
  
  def initialize(env, fix_map={}, loglevel=ERROR)
    @env = env
    @fix_map = fix_map
    @loglevel = loglevel
    @rolestack = []
    @elementstack = []
  end
   
  def add_metamodel(ns, mod)
    @ns_module_map ||={}
    @ns_module_map[ns] = mod
  end  

  def instantiate(str)
    @resolver_descs = []
    @element_by_id = {}
    super(str, 1000)
    @resolver_descs.each do |rd|
      if rd.many
        newval = rd.value.split(" ").collect{|v| @element_by_id[v]}
      else
        newval = @element_by_id[rd.value]
      end
      log WARN, "Could not resolve reference #{rd.attribute} on #{rd.object}" unless newval
      begin
        rd.object.setGeneric(rd.attribute,newval)
      rescue Exception
        log WARN, "Could not set reference #{rd.attribute} on #{rd.object}"
      end
    end
  end

  def start_tag(prefix, tag, namespaces, attributes)
    if tag =~ /\w+\.(\w+)/
      # XMI role
      role_name = map_feature_name($1) || $1
      eRef = @elementstack.last && eAllReferences(@elementstack.last).find{|r|r.name == role_name}
      log WARN, "No reference found for #{role_name} on #{@elementstack.last}" unless eRef
      @rolestack.push eRef
    elsif attributes["xmi.idref"]
      # reference
      rd = ResolverDescription.new
      rd.object = @elementstack.last
      rd.attribute = @rolestack.last.name
      rd.value = attributes["xmi.idref"]
      rd.many = @rolestack.last.many      
      @resolver_descs << rd
      @elementstack.push nil
    else
      # model element
      value = map_tag(tag, attributes) || tag
      if value.is_a?(String)
        mod = @ns_module_map[namespaces[prefix]]
        unless mod
          log WARN, "Ignoring tag #{tag}"
          return
        end
        value = mod.const_get(value).new
      end
      @env << value
      eRef = @rolestack.last
      if eRef && eRef.many
        @elementstack.last.addGeneric(eRef.name, value)
      elsif eRef
        @elementstack.last.setGeneric(eRef.name, value)
      end
      @elementstack.push value
    end
  end
  
  def end_tag(prefix, tag)
    if tag =~ /\w+\.(\w+)/
      @rolestack.pop
    else
      @elementstack.pop
    end
  end  
  
  def set_attribute(attr, value)
    return unless @elementstack.last
    if attr == "xmi.id"
      @element_by_id[value] = @elementstack.last
    else
      attr_name = map_feature_name(attr) || attr
      eFeat = eAllStructuralFeatures(@elementstack.last).find{|a| a.name == attr_name}
      unless eFeat
        log WARN, "No structural feature found for #{attr_name} on #{@elementstack.last}"
        return
      end
      if eFeat.is_a?(RGen::ECore::EReference)
        if map_feature_value(attr_name, value).is_a?(eFeat.eType.instanceClass)
          @elementstack.last.setGeneric(attr_name, map_feature_value(attr_name, value))
        else
          rd = ResolverDescription.new
          rd.object = @elementstack.last
          rd.attribute = attr_name
          rd.value = value
          rd.many = eFeat.many
          @resolver_descs << rd
        end
      else
        value = map_feature_value(attr_name, value) || value
        value = true if value == "true" && eFeat.eType == EBoolean
        value = false if value == "false" && eFeat.eType == EBoolean
        value = value.to_i if eFeat.eType == EInt || eFeat.eType == ELong
        value = value.to_f if eFeat.eType == EFloat
        value = value.to_sym if eFeat.eType.is_a?(EEnum)
        @elementstack.last.setGeneric(attr_name, value)
      end
    end
  end
  
  private
  
  def map_tag(tag, attributes)
    tag_map = @fix_map[:tags] || {}
    value = tag_map[tag]
    if value.is_a?(Proc)
      value.call(tag, attributes)
    else
      value
    end 
  end
        
  def map_feature_name(name)
    name_map = @fix_map[:feature_names] || {}
    name_map[name]
  end
  
  def map_feature_value(attr_name, value)
    value_map = @fix_map[:feature_values] || {}
    map = value_map[attr_name]
    if map.is_a?(Hash)
      map[value]
    elsif map.is_a?(Proc)
      map.call(value)
    end
  end
  
  def log(level, msg)
    puts %w(INFO WARN ERROR)[level] + ": " + msg if level >= @loglevel
  end

  def eAllReferences(element)
    @eAllReferences ||= {}
    @eAllReferences[element.class] ||= element.class.ecore.eAllReferences
  end
    
  def eAllStructuralFeatures(element)
    @eAllStructuralFeatures ||= {}
    @eAllStructuralFeatures[element.class] ||= element.class.ecore.eAllStructuralFeatures
  end
  
end
