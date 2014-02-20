# FIXME: This module should be updated when a newer version of RGen (>0.6.2) adds required meta model "e-method" supports.
#
require 'rgen/ecore/ecore'
module Puppet::Pops::Containment
  # Returns Enumerable, thus allowing
  # some_element.eAllContents each {|contained| }
  # This is a depth first enumeration where parent appears before children.
  # @note the top-most object itself is not included in the enumeration, only what it contains.
  def eAllContents
    EAllContentsEnumerator.new(self)
  end

  def eAllContainers
    EAllContainersEnumerator.new(self)
  end

  class EAllContainersEnumerator
    include Enumerable

    def initialize o
      @element = o
    end

    def each &block
      if block_given?
        eAllContainers(@element, &block)
      else
        self
      end
    end

    def eAllContainers(element, &block)
      x = element.eContainer
      while !x.nil? do
        yield x
        x = x.eContainer
      end
    end

  end

  class EAllContentsEnumerator
    include Enumerable
    def initialize o
      @element = o
      @@cache ||= {}
    end

    def each &block
      if block_given?
        eAllContents(@element, &block)
        @element
      else
        self
      end
    end

    def eAllContents(element, &block)
      # This method is performance critical and code has been manually in-lined.
      # Resist the urge to make this pretty.
      # The slow way is element.eAllContainments.each {|c| element.getGenericsAsArray(c.name) }
      #
      (@@cache[element.class] || all_containment_getters(element)).each do |r|
        children = element.send(r)
        if children.is_a?(Array)
          children.each do |c|
            yield c
            eAllContents(c, &block)
          end
        elsif !children.nil?
          yield children
          eAllContents(children, &block)
        end
      end
    end

    private

    def all_containment_getters(element)
      elem_class = element.class
      containments = []
      collect_getters(elem_class.ecore, containments)
      @@cache[elem_class] = containments
    end

    def collect_getters(eclass, containments)
        eclass.eStructuralFeatures.select {|r| r.is_a?(RGen::ECore::EReference) && r.containment}.each do |r|
          n = r.name
          containments << :"get#{n[0..0].upcase + ( n[1..-1] || "" )}"
        end
        eclass.eSuperTypes.each do |t|
          if cached = @@cache[ t.instanceClass ]
            containments.concat(cached)
          else
            super_containments = []
            collect_getters(t, super_containments)
            @@cache[ t.instanceClass ] = super_containments
            containments.concat(super_containments)
          end
      end
    end

  end
end
