require 'rgen/instantiator/reference_resolver'

module RGen

module Instantiator

# This is a resolver resolving element identifiers which are qualified names.
class QualifiedNameResolver

  attr_reader :nameAttribute
  attr_reader :separator
  attr_reader :leadingSeparator

  def initialize(rootElements, options={})
    @rootElements = rootElements
    @nameAttribute = options[:nameAttribute] || "name"
    @separator = options[:separator] || "/"
    @leadingSeparator = options.has_key?(:leadingSeparator) ? options[:leadingSeparator] : true
    @elementByQName = {}
    @visitedQName = {}
    @childReferences = {}
    @resolverDelegate = ReferenceResolver.new(:identifier_resolver => method(:resolveIdentifier))
  end

  def resolveIdentifier(qualifiedName)
    return @elementByQName[qualifiedName] if @elementByQName.has_key?(qualifiedName)
    path = qualifiedName.split(separator).reject{|s| s == ""}
    if path.size > 1
      parentQName = (leadingSeparator ? separator : "") + path[0..-2].join(separator)
      parents = resolveIdentifier(parentQName)
      parents = [parents].compact unless parents.is_a?(Array)
      children = parents.collect{|p| allNamedChildren(p)}.flatten
    elsif path.size == 1
      parentQName = ""
      children = allRootNamedChildren
    else
      return @elementByQName[qualifiedName] = nil
    end
    # if the parent was already visited all matching elements are the hash 
    if !@visitedQName[parentQName]
      children.each do |c|
        name = c.send(nameAttribute)
        if name
          qname = parentQName + ((parentQName != "" || leadingSeparator) ? separator : "") + name
          existing = @elementByQName[qname]
          if existing 
            @elementByQName[qname] = [existing] unless existing.is_a?(Array)
            @elementByQName[qname] << c
          else
            @elementByQName[qname] = c 
          end
        end
      end
      # all named children of praent have been checked and hashed
      @visitedQName[parentQName] = true
    end
    @elementByQName[qualifiedName] ||= nil
  end

  def resolveReferences(unresolvedReferences, problems=[])
    @resolverDelegate.resolve(unresolvedReferences, :problems => problems)
  end

  private

  def allNamedChildren(element)
    childReferences(element.class).collect do |r|
      element.getGenericAsArray(r.name).collect do |c|
        if c.respond_to?(nameAttribute)
          c
        else
          allNamedChildren(c)
        end
      end
    end.flatten
  end

  def allRootNamedChildren
    @rootElements.collect do |e|
      if e.respond_to?(nameAttribute)
        e
      else
        allNamedChildren(e)
      end
    end.flatten
  end

  def childReferences(clazz)
    @childReferences[clazz] ||= clazz.ecore.eAllReferences.select{|r| r.containment}
  end

end

end

end

