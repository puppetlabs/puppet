$:.unshift File.join(File.dirname(__FILE__),"..","test")

require 'metamodel_builder_test'
require 'rgen/ecore/ecore_to_ruby'

# this test suite runs all the tests of MetamodelBuilderTest with the TestMetamodel 
# replaced by the result of feeding its ecore model through ECoreToRuby
# 
class MetamodelFromEcoreTest < MetamodelBuilderTest
  
  # clone the ecore model, because it will be modified below
  test_ecore = Marshal.load(Marshal.dump(TestMetamodel.ecore))
  # some EEnum types are not hooked into the EPackage because they do not
  # appear with a constant assignment in TestMetamodel
  # fix this by explicitly assigning the ePackage
  # also fix the name of anonymous enums
  test_ecore.eClassifiers.find{|c| c.name == "SimpleClass"}.
    eAttributes.select{|a| a.name == "kind" || a.name == "kindWithDefault"}.each{|a|
      a.eType.name = "KindType"
      a.eType.ePackage = test_ecore}
  test_ecore.eClassifiers.find{|c| c.name == "ManyAttrClass"}.
    eAttributes.select{|a| a.name == "enums"}.each{|a|
      a.eType.name = "ABCEnum"
      a.eType.ePackage = test_ecore}

  MetamodelFromEcore = RGen::ECore::ECoreToRuby.new.create_module(test_ecore)

  def mm
    MetamodelFromEcore
  end

  # alternative implementation for dynamic variant
  def test_bad_default_value_literal
    package = RGen::ECore::EPackage.new(:name => "Package1", :eClassifiers => [
      RGen::ECore::EClass.new(:name => "Class1", :eStructuralFeatures => [
        RGen::ECore::EAttribute.new(:name => "value", :eType => RGen::ECore::EInt, :defaultValueLiteral => "x")])])
    mod = RGen::ECore::ECoreToRuby.new.create_module(package)
    obj = mod::Class1.new
    # the error is raised only when the feature is lazily constructed
    assert_raise StandardError do
      obj.value
    end
  end

  # define all the test methods explicitly in the subclass
  # otherwise minitest is smart enough to run the tests only in the superclass context
  MetamodelBuilderTest.instance_methods.select{|m| m.to_s =~ /^test_/}.each do |m|
    next if instance_methods(false).include?(m)
    module_eval <<-END
      def #{m}
        super
      end
    END
  end

end

