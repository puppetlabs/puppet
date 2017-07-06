module RGen

module Serializer

class JsonSerializer

  def initialize(writer, opts={})
    @writer = writer
    @elementIdentifiers = {}
    @identAttrName = opts[:identAttrName] || "name"
    @separator = opts[:separator] || "/"
    @leadingSeparator = opts.has_key?(:leadingSeparator) ? opts[:leadingSeparator] : true 
    @featureFilter = opts[:featureFilter]
    @identifierProvider = opts[:identifierProvider]
  end

  def elementIdentifier(element)
    ident = @identifierProvider && @identifierProvider.call(element)
    ident || (element.is_a?(RGen::MetamodelBuilder::MMProxy) && element.targetIdentifier) || qualifiedElementName(element)
  end

  # simple identifier calculation based on qualified names
  # prerequisits:
  # * containment relations must be bidirectionsl
  # * local name stored in single attribute +@identAttrName+ for all classes
  #
  def qualifiedElementName(element)
    return @elementIdentifiers[element] if @elementIdentifiers[element]
    localIdent = ((element.respond_to?(@identAttrName) && element.getGeneric(@identAttrName)) || "").strip
    parentRef = element.class.ecore.eAllReferences.select{|r| r.eOpposite && r.eOpposite.containment}.first
    parent = parentRef && element.getGeneric(parentRef.name)
    if parent
      if localIdent.size > 0
        parentIdent = qualifiedElementName(parent)
        result = parentIdent + @separator + localIdent
      else
        result = qualifiedElementName(parent)
      end
    else
      result = (@leadingSeparator ? @separator : "") + localIdent
    end
    @elementIdentifiers[element] = result
  end

  def serialize(elements)
    if elements.is_a?(Array)
      write("[ ")
      elements.each_with_index do |e, i| 
        serializeElement(e)
        write(",\n") unless i == elements.size-1 
      end
      write("]")
    else
      serializeElement(elements)
    end
  end

  def serializeElement(element, indent="")
    write(indent + "{ \"_class\": \""+element.class.ecore.name+"\"")
    element.class.ecore.eAllStructuralFeatures.each do |f|
      next if f.derived
      value = element.getGeneric(f.name)
      unless value == [] || value.nil? || 
        (f.is_a?(RGen::ECore::EReference) && f.eOpposite && f.eOpposite.containment) || 
        (@featureFilter && !@featureFilter.call(f)) 
        write(", ")
        writeFeature(f, value, indent)
      end
    end
    write(" }")
  end

  def writeFeature(feat, value, indent)
    write("\""+feat.name+"\": ")
    if feat.is_a?(RGen::ECore::EAttribute)
      if value.is_a?(Array)
        write("[ "+value.collect{|v| attributeValue(v, feat)}.join(", ")+" ]")
      else
        write(attributeValue(value, feat))
      end
    elsif !feat.containment
      if value.is_a?(Array)
        write("[ "+value.collect{|v| "\""+elementIdentifier(v)+"\""}.join(", ")+" ]")
      else
        write("\""+elementIdentifier(value)+"\"")
      end
    else
      if value.is_a?(Array)
        write("[ \n")
        value.each_with_index do |v, i|
          serializeElement(v, indent+"  ")
          write(",\n") unless i == value.size-1
        end
        write("]")
      else
        write("\n")
        serializeElement(value, indent+"  ")
      end
    end
  end

  def attributeValue(value, a)
    if a.eType == RGen::ECore::EString || a.eType.is_a?(RGen::ECore::EEnum)
      "\""+value.to_s.gsub('\\','\\\\\\\\').gsub('"','\\"').gsub("\n","\\n").gsub("\r","\\r").
        gsub("\t","\\t").gsub("\f","\\f").gsub("\b","\\b")+"\""
    else
      value.to_s
    end
  end
   
  private

  def write(s)
    @writer.write(s) 
  end
end

end

end

