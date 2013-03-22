require 'rgen/transformer'
require 'metamodels/uml13_metamodel'
require 'ea_support/uml13_ea_metamodel'

class UML13EAToUML13 < RGen::Transformer
  include UML13EA
  
  def transform
    trans(:class => Package)
    trans(:class => Class)
    @env_out.find(:class => UML13::Attribute).each do |me|
      # remove tagged vales internally used by EA which have been converted to UML
      me.taggedValue = me.taggedValue.reject{|tv| ["lowerBound", "upperBound"].include?(tv.tag)}
    end
  end
  
  def cleanModel
    @env_out.find(:class => UML13::ModelElement).each do |me|
      me.taggedValue = []
    end
  end
  
  copy_all UML13EA, :to => UML13, :except => %w(
    XmiIdProvider
    AssociationEnd AssociationEndRole
    StructuralFeature
    Attribute
    Generalization
    ActivityModel 
    CompositeState 
    PseudoState
    Dependency
  )  
    
  transform AssociationEndRole, :to => UML13::AssociationEndRole do
    copyAssociationEnd
  end

  transform AssociationEnd, :to => UML13::AssociationEnd do
    copyAssociationEnd
  end
  
  def copyAssociationEnd
    copy_features :except => [:isOrdered, :changeable] do
      {:ordering => isOrdered ? :ordered : :unordered,
       :changeability => {:none => :frozen}[changeable] || changeable,
       :aggregation => {:shared => :aggregate}[aggregation] || aggregation,
       :multiplicity => UML13::Multiplicity.new(
        :range => [UML13::MultiplicityRange.new(
          :lower => multiplicity && multiplicity.split("..").first,
          :upper => multiplicity && multiplicity.split("..").last)])}
    end
  end

  transform StructuralFeature, :to => UML13::StructuralFeature, 
    :if => lambda{|c| !@current_object.is_a?(UML13EA::Attribute)} do
    copy_features :except => [:changeable] do
      {:changeability => {:none => :frozen}[changeable] }
    end
  end

  transform StructuralFeature, :to => UML13::Attribute, 
    :if => lambda{|c| @current_object.is_a?(UML13EA::Attribute)} do
    _lowerBound = taggedValue.find{|tv| tv.tag == "lowerBound"}
    _upperBound = taggedValue.find{|tv| tv.tag == "upperBound"}
    if _lowerBound || _upperBound
      _multiplicity = UML13::Multiplicity.new(
        :range => [UML13::MultiplicityRange.new(
          :lower => (_lowerBound && _lowerBound.value) || "0",
          :upper => (_upperBound && _upperBound.value) || "1"
        )])
    end
    copy_features :except => [:changeable] do
      {:changeability => {:none => :frozen}[changeable],
       :multiplicity => _multiplicity }
    end
  end

  transform Generalization, :to => UML13::Generalization do
    copy_features :except => [:subtype, :supertype] do 
      { :child => trans(subtype),
        :parent => trans(supertype) }
    end
  end
  
  copy ActivityModel, :to => UML13::ActivityGraph

  transform CompositeState, :to => UML13::CompositeState do
    copy_features :except => [:substate] do
      { :subvertex => trans(substate) }
    end
  end
  
  copy PseudoState, :to => UML13::Pseudostate

  transform Dependency, :to => UML13::Dependency do
    _name_tag = taggedValue.find{|tv| tv.tag == "dst_name"}
    copy_features do
      { :name => (_name_tag && _name_tag.value) || "Anonymous" }
    end
  end
  
end
