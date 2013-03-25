require 'rgen/serializer/xml_serializer'

module RGen

module Serializer

class XMI11Serializer < XMLSerializer

  def initialize(file)
    super
    @namespacePrefix = ""
    @contentLevelElements = []
  end
  
  def setNamespace(shortcut, url)
    @namespaceShortcut = shortcut
    @namespaceUrl = url
    @namespacePrefix = shortcut+":"
  end
  
  def serialize(rootElement, headerInfo=nil)
    attrs = []
    attrs << ['xmi.version', "1.1"]
    attrs << ['xmlns:'+@namespaceShortcut, @namespaceUrl] if @namespaceUrl
    attrs << ['timestamp', Time.now.to_s]
    startTag("XMI", attrs)
    if headerInfo
      startTag("XMI.header")
      writeHeaderInfo(headerInfo)
      endTag("XMI.header")
    end
    startTag("XMI.content")
    @contentLevelElements = []
    writeElement(rootElement)
    # write remaining toplevel elements, each of which could have
    # more toplevel elements as childs
    while @contentLevelElements.size > 0
      writeElement(@contentLevelElements.shift)
    end
    endTag("XMI.content") 
    endTag("XMI") 
  end
  
  def writeHeaderInfo(hash)
    hash.each_pair do |k,v|
      tag = "XMI." + k.to_s
      startTag(tag)
      if v.is_a?(Hash)
        writeHeaderInfo(v)
      else
        writeText(v.to_s)
      end
      endTag(tag)
    end
  end
  
  def writeElement(element)
    tag = @namespacePrefix + element.class.ecore.name
    attrs = attributeValues(element)
    startTag(tag, attrs)
    containmentReferences(element).each do |r|
      roletag = @namespacePrefix + r.eContainingClass.name + "." + r.name
      targets = element.getGeneric(r.name)
      targets = [ targets ] unless targets.is_a?(Array)
      targets.compact!
      next if targets.empty?
      startTag(roletag)
      targets.each do |t|
        if xmiLevel(t) == :content
          @contentLevelElements << t
        else
          writeElement(t)
        end
      end
      endTag(roletag)
    end
    endTag(tag)
  end

  def attributeValues(element)
    result = [["xmi.id", xmiId(element)]]
    eAllAttributes(element).select{|a| !a.derived}.each do |a|
      val = element.getGeneric(a.name)
      result << [a.name, val] unless val.nil? || val == ""
    end
    eAllReferences(element).each do |r|
      next if r.derived
      next if r.containment
      next if r.eOpposite && r.eOpposite.containment && xmiLevel(element).nil?
      next if r.eOpposite && r.many && !r.eOpposite.many
      targetElements = element.getGenericAsArray(r.name)
      targetElements.compact!
      val = targetElements.collect{|te| xmiId(te)}.compact.join(' ')
      result << [r.name, val] unless val == ""
    end
    result  
  end
  
  def xmiId(element)
    if element.respond_to?(:_xmi_id) && element._xmi_id
      element._xmi_id.to_s
    else
      element.object_id.to_s
    end
  end
  
  def xmiLevel(element)
    return nil unless element.respond_to?(:_xmi_level) 
    element._xmi_level
  end
  
end

end

end
