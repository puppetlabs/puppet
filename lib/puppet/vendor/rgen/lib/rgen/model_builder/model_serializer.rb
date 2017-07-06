require 'rgen/array_extensions'
require 'rgen/ecore/ecore_ext'

module RGen
  
module ModelBuilder

class ModelSerializer
  
  def initialize(writable, rootPackage)
    @writable = writable
    @currentPackage = rootPackage
    @qualifiedElementName = {}
    @internalElementName = {}
    @relativeQualifiedElementName = {}
  end
  
  def serialize(elements)
    calcQualifiedElementNames(elements)
    unifyQualifiedElementNames
    elements = [elements] unless elements.is_a?(Enumerable)
    elements.each do |e|
      serializeElement(e)
    end
  end
  
  private
  
  def serializeElement(element, viaRef=nil, namePath=[], indent=0)
    className = element.class.ecore.name
    cmd = className[0..0].downcase+className[1..-1]
    args = ["\"#{@internalElementName[element]}\""]
    namePath = namePath + [@internalElementName[element]]
    childs = [] 
    eAllStructuralFeatures(element).each do |f|
      next if f.derived
      if f.is_a?(RGen::ECore::EAttribute)
        next if f.name == "name" && element.name == @internalElementName[element]
        val = element.getGeneric(f.name)
        #puts f.defaultValue.inspect if f.name == "isRoot"
        args << ":#{f.name} => #{serializeAttribute(val)}" unless val == f.defaultValue || val.nil?
      elsif !f.containment
        next if f.eOpposite && f.eOpposite == viaRef
        val = element.getGeneric(f.name)
        refString = serializeReference(element, f, val)
        args << ":#{f.name} => #{refString}" if refString
      else
        cs = element.getGeneric(f.name)
        refString = nil
        if cs.is_a?(Array)
          cs.compact!
          rcs = cs.select{|c| serializeChild?(c, namePath)}
          childs << [f, rcs] unless rcs.empty?
          refString = serializeReference(element, f, cs-rcs)
        else
          if cs && serializeChild?(cs, namePath)
            childs << [f, [cs]]
          else
            refString = serializeReference(element, f, cs)
          end
        end
        args << ":#{f.name} => #{refString}" if refString
      end
    end

    args << ":as => :#{viaRef.name}" if viaRef && containmentRefs(viaRef.eContainingClass, element.class.ecore).size > 1
    cmd = elementPackage(element)+"."+cmd if elementPackage(element).size > 0
    @writable.write "  " * indent + cmd + " " + args.join(", ")
    if childs.size > 0
      @writable.write " do\n"
      oldPackage, @currentPackage = @currentPackage, element.class.ecore.ePackage
      childs.each do |pair|
        f, cs = pair
        cs.each {|c| serializeElement(c, f, namePath, indent+1) }
      end
      @currentPackage = oldPackage
      @writable.write "  " * indent + "end\n"
    else
      @writable.write "\n"
    end
  end
  
  def serializeChild?(child, namePath)
    @qualifiedElementName[child][0..-2] == namePath
  end

  def serializeAttribute(value)
    if value.is_a?(String)
      "\"#{value.gsub("\"","\\\"")}\""
    elsif value.is_a?(Symbol)
      ":#{value}"
    elsif value.nil?
      "nil"
    else
      value.to_s
    end
  end
  
  def serializeReference(element, ref, value)
    if value.is_a?(Array)
      value = value.compact
      value = value.select{|v| compareWithOppositeReference(ref, element, v) > 0} if ref.eOpposite
      qualNames = value.collect do |v|
        relativeQualifiedElementName(v, element).join(".")
      end
      !qualNames.empty? && ("[" + qualNames.collect { |v| "\"#{v}\"" }.join(", ") + "]")
    elsif value && (!ref.eOpposite || compareWithOppositeReference(ref, element, value) > 0)
      qualName = relativeQualifiedElementName(value, element).join(".")
      ("\"#{qualName}\"")        
    end
  end
  
  # descide which part of a bidirectional reference get serialized
  def compareWithOppositeReference(ref, element, target)
    result = 0
    # first try to make the reference from the many side to the one side
    result = -1 if ref.many && !ref.eOpposite.many
    result = 1 if !ref.many && ref.eOpposite.many
    return result if result != 0
    # for 1:1 or many:many perfer, shorter references
    result = relativeQualifiedElementName(element, target).size <=> 
      relativeQualifiedElementName(target, element).size
    return result if result != 0
    # there just needs to be a descision, use class name or object_id
    result = element.class.name <=> target.class.name
    return result if result != 0
    element.object_id <=> target.object_id    
  end

  def elementPackage(element)
    @elementPackage ||= {}
    return @elementPackage[element] if @elementPackage[element]
    eNames = element.class.ecore.ePackage.qualifiedName.split("::")
    rNames = @currentPackage.qualifiedName.split("::")
    while eNames.first == rNames.first && !eNames.first.nil?
      eNames.shift
      rNames.shift
    end
    @elementPackage[element] = eNames.join("::")
  end
  
  def relativeQualifiedElementName(element, context)
    return @relativeQualifiedElementName[[element, context]] if @relativeQualifiedElementName[[element, context]]
    # elements which are not in the @qualifiedElementName Hash are not in the scope
    # of this serialization and will be ignored
    return [] if element.nil? || @qualifiedElementName[element].nil?
    return [] if context.nil? || @qualifiedElementName[context].nil?
    eNames = @qualifiedElementName[element].dup
    cNames = @qualifiedElementName[context].dup
    while eNames.first == cNames.first && eNames.size > 1
      eNames.shift
      cNames.shift
    end
    @relativeQualifiedElementName[[element, context]] = eNames
  end

  def calcQualifiedElementNames(elements, prefix=[], takenNames=[])
    elements = [elements] unless elements.is_a?(Array)
    elements.compact!
    elements.each do |element|
      qualifiedNamePath = prefix + [calcInternalElementName(element, takenNames)]
      @qualifiedElementName[element] ||= []
      @qualifiedElementName[element] << qualifiedNamePath
      takenChildNames = []
      eAllStructuralFeatures(element).each do |f|
        if f.is_a?(RGen::ECore::EReference) && f.containment
          childs = element.getGeneric(f.name)
          calcQualifiedElementNames(childs, qualifiedNamePath, takenChildNames)
        end
      end
    end
  end
  
  def unifyQualifiedElementNames
    @qualifiedElementName.keys.each do |k|
      @qualifiedElementName[k] = @qualifiedElementName[k].sort{|a,b| a.size <=> b.size}.first    
    end
  end

  def calcInternalElementName(element, takenNames)
    return @internalElementName[element] if @internalElementName[element]
    name = if element.respond_to?(:name) && element.name && !element.name.empty?
        element.name
      else
        nextElementHelperName(element)
      end
    while takenNames.include?(name)
      name = nextElementHelperName(element)
    end
    takenNames << name
    @internalElementName[element] = name 
  end
  
  def nextElementHelperName(element)
    eClass = element.class.ecore
    @nextElementNameId ||= {}
    @nextElementNameId[eClass] ||= 1
    result = "_#{eClass.name}#{@nextElementNameId[eClass]}"
    @nextElementNameId[eClass] += 1
    result
  end

  def eAllStructuralFeatures(element)
    @eAllStructuralFeatures ||= {}
    @eAllStructuralFeatures[element.class] ||= element.class.ecore.eAllStructuralFeatures
  end
    
  def eAllReferences(eClass)
    @eAllReferences ||= {}
    @eAllReferences[eClass] ||= eClass.eAllReferences
  end
    
  def containmentRefs(contextClass, eClass)
    @containmentRefs ||= {}
    @containmentRefs[[contextClass, eClass]] ||=
      eAllReferences(contextClass).select do |r| 
        r.containment && (eClass.eAllSuperTypes << eClass).include?(r.eType)
      end
  end

end

end

end
