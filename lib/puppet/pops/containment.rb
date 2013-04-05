# FIXME: This module should be updated when a newer version of RGen (>0.6.2) adds required meta model "e-method" supports.
#
module Puppet::Pops::Containment
  # Returns Enumerable, thus allowing
  # some_element.eAllContents each {|contained| }
  # This is a depth first enumeration where parent appears before children.
  # @note the top-most object itself is not included in the enumeration, only what it contains.
  def eAllContents
    EAllContentsEnumerator.new(self)
  end

  class EAllContentsEnumerator
    include Enumerable
    def initialize o
      @element = o
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
      element.class.ecore.eAllReferences.select{|r| r.containment}.each do |r|
        children = element.getGenericAsArray(r.name)
        children.each do |c|
          block.call(c)
          eAllContents(c, &block)
        end
      end
    end
  end
end
