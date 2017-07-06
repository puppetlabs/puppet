require 'rgen/ecore/ecore'

module RGen
  
module ECore

class ECoreToRuby
  
  def initialize
    @modules = {}
    @classifiers = {}
    @features_added = {}
    @in_create_module = false
  end

  def create_module(epackage)
    return @modules[epackage] if @modules[epackage]
    
    top = (@in_create_module == false)
    @in_create_module = true

    m = Module.new do
      extend RGen::MetamodelBuilder::ModuleExtension
    end
    @modules[epackage] = m

    epackage.eSubpackages.each{|p| create_module(p)}
    m._set_ecore_internal(epackage)

    create_module(epackage.eSuperPackage).const_set(epackage.name, m) if epackage.eSuperPackage

    # create classes only after all modules have been created
    # otherwise classes may be created multiple times
    if top
      epackage.eAllClassifiers.each do |c| 
        if c.is_a?(RGen::ECore::EClass)
          create_class(c)
        elsif c.is_a?(RGen::ECore::EEnum)
          create_enum(c)
        end
      end
      @in_create_module = false
    end
    m
  end

  def create_class(eclass)
    return @classifiers[eclass] if @classifiers[eclass]

    c = Class.new(super_class(eclass)) do
      abstract if eclass.abstract
      class << self
        attr_accessor :_ecore_to_ruby
      end
    end
    class << eclass
      attr_accessor :instanceClass
      def instanceClassName
        instanceClass.to_s
      end
    end
    eclass.instanceClass = c
    c::ClassModule.module_eval do
      alias _method_missing method_missing
      def method_missing(m, *args)
        if self.class._ecore_to_ruby.add_features(self.class.ecore)
          send(m, *args)
        else
          _method_missing(m, *args)
        end
      end
      alias _respond_to respond_to?
      def respond_to?(m, include_all=false)
        self.class._ecore_to_ruby.add_features(self.class.ecore)
        _respond_to(m)
      end
    end
    @classifiers[eclass] = c
    c._set_ecore_internal(eclass)
    c._ecore_to_ruby = self

    create_module(eclass.ePackage).const_set(eclass.name, c)
    c
  end

  def create_enum(eenum)
    return @classifiers[eenum] if @classifiers[eenum]

    e = RGen::MetamodelBuilder::DataTypes::Enum.new(eenum.eLiterals.collect{|l| l.name.to_sym})
    @classifiers[eenum] = e

    create_module(eenum.ePackage).const_set(eenum.name, e)
    e
  end

  class FeatureWrapper
    def initialize(efeature, classifiers)
      @efeature = efeature
      @classifiers = classifiers
    end
    def value(prop)
      return false if prop == :containment && @efeature.is_a?(RGen::ECore::EAttribute)
      @efeature.send(prop)
    end
    def many?
      @efeature.many
    end
    def reference?
      @efeature.is_a?(RGen::ECore::EReference)
    end
    def opposite
      @efeature.eOpposite
    end
    def impl_type
      etype = @efeature.eType
      if etype.is_a?(RGen::ECore::EClass) || etype.is_a?(RGen::ECore::EEnum)
        @classifiers[etype]
      else
        ic = etype.instanceClass
        if ic
          ic
        else
          raise "unknown type: #{etype.name}" 
        end
      end
    end
  end

  def add_features(eclass)
    return false if @features_added[eclass]
    c = @classifiers[eclass]
    eclass.eStructuralFeatures.each do |f|
      w1 = FeatureWrapper.new(f, @classifiers) 
      w2 = FeatureWrapper.new(f.eOpposite, @classifiers) if f.is_a?(RGen::ECore::EReference) && f.eOpposite
      c.module_eval do
        if w1.many?
          _build_many_methods(w1, w2)
        else
          _build_one_methods(w1, w2)
        end
      end
    end
    @features_added[eclass] = true
    eclass.eSuperTypes.each do |t|
      add_features(t)
    end
    true
  end

  def super_class(eclass)
    super_types = eclass.eSuperTypes
    case super_types.size
    when 0
      RGen::MetamodelBuilder::MMBase
    when 1
      create_class(super_types.first)
    else
      RGen::MetamodelBuilder::MMMultiple(*super_types.collect{|t| create_class(t)})
    end
  end

end

end

end

