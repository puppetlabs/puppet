$:.unshift File.dirname(__FILE__)+"/../lib"

require 'test/unit'
require 'rgen/ecore/ecore'
require 'rgen/model_builder/builder_context'

class BuilderContextTest < Test::Unit::TestCase
  
  module BuilderExtension1
    module PackageA
      def inPackAExt
        3
      end
      module PackageB
        def inPackBExt
          5  
        end
      end
    end
  end
  
  class BuilderContext
    def inBuilderContext
      7
    end
  end
  
  def test_extensionContainerFactory
    aboveRoot = RGen::ECore::EPackage.new(:name => "AboveRoot")
    root = RGen::ECore::EPackage.new(:name => "Root", :eSuperPackage => aboveRoot)
    packageA = RGen::ECore::EPackage.new(:name => "PackageA", :eSuperPackage => root)
    packageB = RGen::ECore::EPackage.new(:name => "PackageB", :eSuperPackage => packageA)
    packageC = RGen::ECore::EPackage.new(:name => "PackageBC", :eSuperPackage => packageA)
    
    factory = RGen::ModelBuilder::BuilderContext::ExtensionContainerFactory.new(root, BuilderExtension1, BuilderContext.new)
    
    assert_equal BuilderExtension1::PackageA, factory.moduleForPackage(packageA)
    
    packAExt = factory.extensionContainer(packageA)
    assert packAExt.respond_to?(:inPackAExt)
    assert !packAExt.respond_to?(:inPackBExt)
    assert_equal 3, packAExt.inPackAExt
    assert_equal 7, packAExt.inBuilderContext
    
    assert_equal BuilderExtension1::PackageA::PackageB, factory.moduleForPackage(packageB)
    
    packBExt = factory.extensionContainer(packageB)
    assert !packBExt.respond_to?(:inPackAExt)
    assert packBExt.respond_to?(:inPackBExt)
    assert_equal 5, packBExt.inPackBExt
    assert_equal 7, packBExt.inBuilderContext
    
    assert_raise RuntimeError do
      # aboveRoot is not contained within root
      assert_nil factory.moduleForPackage(aboveRoot)
    end
    assert_nil factory.moduleForPackage(packageC)
  end
end