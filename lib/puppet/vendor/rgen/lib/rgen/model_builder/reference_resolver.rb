require 'rgen/array_extensions'

module RGen
  
module ModelBuilder

class ReferenceResolver
  ResolverJob = Struct.new(:receiver, :reference, :namespace, :string)
  
  class ResolverException < Exception
  end

  class ToplevelNamespace
    def initialize(ns)
      raise "Namespace must be an Enumerable" unless ns.is_a?(Enumerable)
      @ns = ns
    end
    def elements
      @ns
    end
  end
  
  def initialize
    @jobs = []
    @elementName = {}
  end

  def addJob(job)
    @jobs << job
  end
  
  def setElementName(element, name)
    @elementName[element] = name
  end

  def resolve(ns=[])
    @toplevelNamespace = ToplevelNamespace.new(ns)
    (@jobs || []).each_with_index do |job, i|
      target = resolveReference(job.namespace || @toplevelNamespace, job.string.split("."))
      raise ResolverException.new("Can not resolve reference #{job.string}") unless target
      if job.reference.many
        job.receiver.addGeneric(job.reference.name, target)
      else
        job.receiver.setGeneric(job.reference.name, target)
      end
    end
  end
  
  private
  
  # TODO: if a reference can not be fully resolved, but a prefix can be found,
  # the exception reported is that its first path element can not be found on
  # toplevel
  def resolveReference(namespace, nameParts)
    element = resolveReferenceDownwards(namespace, nameParts)
    if element.nil? && parentNamespace(namespace)
      element = resolveReference(parentNamespace(namespace), nameParts)
    end
    element
  end
  
  def resolveReferenceDownwards(namespace, nameParts)
    firstPart, *restParts = nameParts
    element = namespaceElementByName(namespace, firstPart)
    return nil unless element
    if restParts.size > 0
      resolveReferenceDownwards(element, restParts)
    else
      element
    end
  end
  
  def namespaceElementByName(namespace, name)
    @namespaceElementsByName ||= {}
    return @namespaceElementsByName[namespace][name] if @namespaceElementsByName[namespace]
    hash = {}
    namespaceElements(namespace).each do |e|
      raise ResolverException.new("Multiple elements named #{elementName(e)} found in #{nsToS(namespace)}") if hash[elementName(e)]
      hash[elementName(e)] = e if elementName(e)
    end
    @namespaceElementsByName[namespace] = hash
    hash[name]
  end
  
  def parentNamespace(namespace)
    if namespace.class.respond_to?(:ecore)
      parents = elementParents(namespace)
      raise ResolverException.new("Element #{nsToS(namespace)} has multiple parents") \
        if parents.size > 1
      parents.first || @toplevelNamespace
    else
      nil
    end
  end
  
  def namespaceElements(namespace)
    if namespace.is_a?(ToplevelNamespace)
      namespace.elements
    elsif namespace.class.respond_to?(:ecore)
      elementChildren(namespace)
    else
      raise ResolverException.new("Element #{nsToS(namespace)} can not be used as a namespace")
    end
  end
  
  def nsToS(namespace)
    if namespace.is_a?(ToplevelNamespace)
      "toplevel namespace"
    else
      result = namespace.class.name    
      result += ":\"#{elementName(namespace)}\"" if elementName(namespace)
      result
    end
  end
  
  def elementName(element)
    @elementName[element]
  end
  
  def elementChildren(element)
    @elementChildren ||= {}
    return @elementChildren[element] if @elementChildren[element]
    children = containmentRefs(element).collect do |r|
      element.getGeneric(r.name)
    end.flatten.compact
    @elementChildren[element] = children
  end
  
  def elementParents(element)
    @elementParents ||= {}
    return @elementParents[element] if @elementParents[element]
    parents = parentRefs(element).collect do |r|
      element.getGeneric(r.name)
    end.flatten.compact
    @elementParents[element] = parents
  end  
  
  def containmentRefs(element)
    @containmentRefs ||= {}
    @containmentRefs[element.class] ||= eAllReferences(element).select{|r| r.containment}
  end
  
  def parentRefs(element)
    @parentRefs ||= {}
    @parentRefs[element.class] ||= eAllReferences(element).select{|r| r.eOpposite && r.eOpposite.containment}
  end

  def eAllReferences(element)
    @eAllReferences ||= {}
    @eAllReferences[element.class] ||= element.class.ecore.eAllReferences
  end
end

end

end