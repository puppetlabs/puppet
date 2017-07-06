$:.unshift File.join(File.dirname(__FILE__),"..","lib")

require 'test/unit'
require 'rgen/environment'
require 'rgen/metamodel_builder'

class EnvironmentTest < Test::Unit::TestCase

	class Model
		attr_accessor :name
	end
	
	class ModelSub < Model
	end
	
	class ClassSuperA < RGen::MetamodelBuilder::MMBase
	end
	
	class ClassSuperB < RGen::MetamodelBuilder::MMBase
	end
	
	class ClassC < RGen::MetamodelBuilder::MMMultiple(ClassSuperA, ClassSuperB)
		has_attr 'name', String
	end
	
	class ClassSubD < ClassC
	end
	
	class ClassSubE < ClassC
	end

	def test_find_mmbase
		env = RGen::Environment.new
		mA1 = env.new(ClassSuperA)
		mB1 = env.new(ClassSuperB)
		mD1 = env.new(ClassSubD, :name => "mD1")
		mD2 = env.new(ClassSubD, :name => "mD2")
		mE = env.new(ClassSubE, :name => "mE")
		
		resultA = env.find(:class => ClassSuperA)
		assert_equal sortById([mA1,mD1,mD2,mE]), sortById(resultA)
		resultNamedA = env.find(:class => ClassSuperA, :name => "mD1")
		assert_equal sortById([mD1]), sortById(resultNamedA)
		
		resultB = env.find(:class => ClassSuperB)
		assert_equal sortById([mB1,mD1,mD2,mE]), sortById(resultB)
		resultNamedB = env.find(:class => ClassSuperB, :name => "mD1")
		assert_equal sortById([mD1]), sortById(resultNamedB)
		
		resultC = env.find(:class => ClassC)
		assert_equal sortById([mD1,mD2,mE]), sortById(resultC)
		
		resultD = env.find(:class => ClassSubD)
		assert_equal sortById([mD1,mD2]), sortById(resultD)
	end
	
	def test_find
		m1 = Model.new
		m1.name = "M1"
		m2 = ModelSub.new
		m2.name = "M2"
		m3 = "justAString"
		env = RGen::Environment.new << m1 << m2 << m3
		
		result = env.find(:class => Model, :name => "M1")
		assert result.is_a?(Array)
		assert_equal 1, result.size
		assert_equal m1, result.first

		result = env.find(:class => Model)
		assert result.is_a?(Array)
		assert_equal sortById([m1,m2]), sortById(result)
		
		result = env.find(:name => "M2")
		assert result.is_a?(Array)
		assert_equal 1, result.size
		assert_equal m2, result.first		
		
		result = env.find(:class => [Model, String])
		assert result.is_a?(Array)
		assert_equal sortById([m1,m2,m3]), sortById(result)
	end
	
	private
	
	def sortById(array)
		array.sort{|a,b| a.object_id <=> b.object_id}
	end
	
end
