module Puppet; module Pops; module API
  
# FIXME: This module will be remove when a newer version of RGen (>0.6.0) is in use
# As these methods (+ fully working versions) will be available.
# @deprecated use the real RGen implementation
module Containment
  
  # Returns Enumerable, thus allowing
  # some_element.eAllContents each {|contained| }
  # This is a depth first enumeration where parent appears before children.
  #
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
  
  # TODO: Bummer. Does not work on _uni containment
  def eContainingFeature
    Containment.eContainingFeature(self)
  end
  
  # TODO: Bummer. Does not work on _uni containment
  def Containment.eContainingFeature(element)
    parent_refs = element.class.ecore.eAllReferences.select do |r| 
     r.eOpposite && r.eOpposite.containment
    end
    parent_refs.each do |r|
      parent = element.getGeneric(r.name)
      # there may be several parent refs but only one should hold a value
      return r.eOpposite if parent
   end
  end
  
  # TODO: Bummer. Does not work on _uni containment
  def eContainer
   feat = Containment.eContainingFeature(self)
   feat && self.getGeneric(feat.name)
  end

end
end;end;end