require 'rgen/transformer'
require 'metamodels/uml13_metamodel'
require 'ea_support/uml13_ea_metamodel'
require 'ea_support/uml13_ea_metamodel_ext'

class UML13ToUML13EA < RGen::Transformer
  include UML13
  
  def transform
    trans(:class => Package)
    trans(:class => Class)
  end
  
  copy_all UML13, :to => UML13EA, :except => %w(
    ActivityGraph 
    CompositeState SimpleState
    Class 
    Association AssociationEnd AssociationEndRole
    Generalization
    Pseudostate    
    Attribute
  )  
  
  copy ActivityGraph, :to => UML13EA::ActivityModel
  
  copy Pseudostate, :to => UML13EA::PseudoState
  
  transform CompositeState, :to => UML13EA::CompositeState do
    copy_features :except => [:subvertex] do
      { :substate => trans(subvertex) }
    end
  end
  
  transform SimpleState, :to => UML13EA::SimpleState do
    copy_features :except => [:container] do
      { :taggedValue => trans(taggedValue) + 
        [@env_out.new(UML13EA::TaggedValue, :tag => "ea_stype", :value => "State")] +
        (container ? [ @env_out.new(UML13EA::TaggedValue, :tag => "owner", :value => trans(container)._xmi_id)] : []) }
    end
  end
  
  transform Class, :to => UML13EA::Class do
    copy_features do
      { :taggedValue => trans(taggedValue) + [@env_out.new(UML13EA::TaggedValue, :tag => "ea_stype", :value => "Class")]}
    end
  end
  
  transform Association, :to => UML13EA::Association do
    copy_features do
      { :connection => trans(connection[1].isNavigable ? [connection[0], connection[1]] : [connection[1], connection[0]]),
        :taggedValue => trans(taggedValue) + [
          @env_out.new(UML13EA::TaggedValue, :tag => "ea_type", :value => "Association"),
          @env_out.new(UML13EA::TaggedValue, :tag => "direction", :value => 
            connection.all?{|c| c.isNavigable} ? "Bi-Directional" : "Source -&gt; Destination")] }
    end
  end
  
  transform AssociationEnd, :to => UML13EA::AssociationEnd do 
    copyAssociationEnd
  end
  
  transform AssociationEndRole, :to => UML13EA::AssociationEndRole do 
    copyAssociationEnd
  end
  
  def copyAssociationEnd
    _lower = multiplicity && multiplicity.range.first.lower
    _upper = multiplicity && multiplicity.range.first.upper
    copy_features :except => [:multiplicity, :ordering, :changeability] do
      { :multiplicity => _lower == _upper ? _lower : "#{_lower}..#{_upper}",
        :isOrdered => ordering == :ordered,
        :changeable => :none } #{:frozen => :none}[changeability] || changeability}
    end
  end

  transform Attribute, :to => UML13EA::Attribute do
    copy_features :except => [:changeability] do
      { :changeable => {:frozen => :none}[changeability] }
    end
  end

  transform Generalization, :to => UML13EA::Generalization do
    copy_features :except => [:child, :parent] do
      { :taggedValue => trans(taggedValue) + [@env_out.new(UML13EA::TaggedValue, :tag => "ea_type", :value => "Generalization")],
        :subtype => trans(child),
        :supertype => trans(parent)}
    end
  end
end
