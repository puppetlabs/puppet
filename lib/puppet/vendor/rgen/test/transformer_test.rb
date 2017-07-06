$:.unshift File.join(File.dirname(__FILE__),"..","lib")
$:.unshift File.join(File.dirname(__FILE__),"..","test")

require 'test/unit'
require 'rgen/transformer'
require 'rgen/environment'
require 'rgen/util/model_comparator'
require 'metamodels/uml13_metamodel'
require 'testmodel/class_model_checker'

class TransformerTest < Test::Unit::TestCase

	class ModelIn
		attr_accessor :name
	end

	class ModelInSub < ModelIn
	end
	
	class ModelAIn
		attr_accessor :name
		attr_accessor :modelB
	end

	class ModelBIn
		attr_accessor :name
		attr_accessor :modelA
	end

	class ModelCIn
		attr_accessor :number
	end
	
	class ModelOut
		attr_accessor :name
	end
	
	class ModelAOut
		attr_accessor :name
		attr_accessor :modelB
	end
	
	class ModelBOut
		attr_accessor :name
		attr_accessor :modelA
	end
	
	class ModelCOut
		attr_accessor :number
	end
	
	class MyTransformer < RGen::Transformer
		attr_reader :modelInTrans_count
		attr_reader :modelAInTrans_count
		attr_reader :modelBInTrans_count
		
		transform ModelIn, :to => ModelOut do
			# aribitrary ruby code may be placed before the hash creating the output element
			@modelInTrans_count ||= 0; @modelInTrans_count += 1
			{ :name => name }
		end
		
		transform ModelAIn, :to => ModelAOut do
			@modelAInTrans_count ||= 0; @modelAInTrans_count += 1
			{ :name => name, :modelB => trans(modelB) }
		end
		
		transform ModelBIn, :to => ModelBOut do
			@modelBInTrans_count ||= 0; @modelBInTrans_count += 1
			{ :name => name, :modelA => trans(modelA) }
		end
		
		transform ModelCIn, :to => ModelCOut, :if => :largeNumber do
			# a method can be called anywhere in a transformer block
			{ :number => duplicateNumber }
		end

		transform ModelCIn, :to => ModelCOut, :if => :smallNumber do
			{ :number => number / 2 }
		end
		
		method :largeNumber do
			number > 1000
		end
		
		method :smallNumber do
			number < 500
		end
		
		method :duplicateNumber do
			number * 2;
		end
		
	end
	
	class MyTransformer2 < RGen::Transformer
		# check that subclasses are independent (i.e. do not share the rules)
		transform ModelIn, :to => ModelOut do
			{ :name => name }
		end
	end	
	
	def test_transformer
		from = ModelIn.new
		from.name = "TestName"
		env_out = RGen::Environment.new
		t = MyTransformer.new(:env_in, env_out)
		assert t.trans(from).is_a?(ModelOut)
		assert_equal "TestName", t.trans(from).name
		assert_equal 1, env_out.elements.size
		assert_equal env_out.elements.first, t.trans(from)
		assert_equal 1, t.modelInTrans_count
	end
  
  def test_transformer_chain
    from = ModelIn.new
    from.name = "Test1"
    from2 = ModelIn.new
    from2.name = "Test2"
    from3 = ModelIn.new
    from3.name = "Test3"
    env_out = RGen::Environment.new
    elementMap = {}
    t1 = MyTransformer.new(:env_in, env_out, elementMap)
		assert t1.trans(from).is_a?(ModelOut)
		assert_equal "Test1", t1.trans(from).name
		assert_equal 1, t1.modelInTrans_count
    # modifying the element map means that following calls of +trans+ will be affected
    assert_equal( {from => t1.trans(from)}, elementMap )
    elementMap.merge!({from2 => :dummy})
    assert_equal :dummy, t1.trans(from2)
    # second transformer based on the element map of the first
    t2 = MyTransformer.new(:env_in, env_out, elementMap)
    # second transformer returns same objects
    assert_equal t1.trans(from).object_id, t2.trans(from).object_id
    assert_equal :dummy, t2.trans(from2)
    # and no transformer rule is evaluated at this point
		assert_equal nil, t2.modelInTrans_count
    # now transform a new object in second transformer
		assert t2.trans(from3).is_a?(ModelOut)
		assert_equal "Test3", t2.trans(from3).name
		assert_equal 1, t2.modelInTrans_count
    # the first transformer returns the same object without evaluation of a transformer rule
    assert_equal t1.trans(from3).object_id, t2.trans(from3).object_id
		assert_equal 1, t1.modelInTrans_count
  end
	
	def test_transformer_subclass
		from = ModelInSub.new
		from.name = "TestName"
		t = MyTransformer.new
		assert t.trans(from).is_a?(ModelOut)
		assert_equal "TestName", t.trans(from).name
		assert_equal 1, t.modelInTrans_count
	end
	
	def test_transformer_array
		froms = [ModelIn.new, ModelIn.new]
		froms[0].name = "M1"
		froms[1].name = "M2"
		env_out = RGen::Environment.new
		t = MyTransformer.new(:env_in, env_out)
		assert t.trans(froms).is_a?(Array)
		assert t.trans(froms)[0].is_a?(ModelOut)
		assert_equal "M1", t.trans(froms)[0].name
		assert t.trans(froms)[1].is_a?(ModelOut)
		assert_equal "M2", t.trans(froms)[1].name
		assert_equal 2, env_out.elements.size
		assert (t.trans(froms)-env_out.elements).empty?
		assert_equal 2, t.modelInTrans_count
	end
	
	def test_transformer_cyclic
		# setup a cyclic dependency between fromA and fromB
		fromA = ModelAIn.new
		fromB = ModelBIn.new
		fromA.modelB = fromB
		fromA.name = "ModelA"
		fromB.modelA = fromA
		fromB.name = "ModelB"
		env_out = RGen::Environment.new
		t = MyTransformer.new(:env_in, env_out)
		# check that trans resolves the cycle correctly (no endless loop)
		# both elements, fromA and fromB will be transformed with the transformation
		# of the first element, either fromA or fromB
		assert t.trans(fromA).is_a?(ModelAOut)
		assert_equal "ModelA", t.trans(fromA).name
		assert t.trans(fromA).modelB.is_a?(ModelBOut)
		assert_equal "ModelB", t.trans(fromA).modelB.name
		assert_equal t.trans(fromA), t.trans(fromA).modelB.modelA
		assert_equal t.trans(fromB), t.trans(fromA).modelB
		assert_equal 2, env_out.elements.size
		assert (env_out.elements - [t.trans(fromA), t.trans(fromB)]).empty?
		assert_equal 1, t.modelAInTrans_count
		assert_equal 1, t.modelBInTrans_count
	end
	
	def test_transformer_conditional
		froms = [ModelCIn.new, ModelCIn.new, ModelCIn.new]
		froms[0].number = 100
		froms[1].number = 1000
		froms[2].number = 2000

		env_out = RGen::Environment.new
		t = MyTransformer.new(:env_in, env_out)

		assert t.trans(froms).is_a?(Array)
		assert_equal 2, t.trans(froms).size
		
		# this one matched the smallNumber rule
		assert t.trans(froms[0]).is_a?(ModelCOut)
		assert_equal 50, t.trans(froms[0]).number
		
		# this one did not match any rule
		assert t.trans(froms[1]).nil?

		# this one matched the largeNumber rule
		assert t.trans(froms[2]).is_a?(ModelCOut)
		assert_equal 4000, t.trans(froms[2]).number
		
		# elements in environment are the same as the ones returned
		assert_equal 2, env_out.elements.size
		assert (t.trans(froms)-env_out.elements).empty?
	end
	
	class CopyTransformer < RGen::Transformer
		include UML13
		def transform
			trans(:class => UML13::Package)
		end
		UML13.ecore.eClassifiers.each do |c|
		  copy c.instanceClass 
    end
	end

	MODEL_DIR = File.join(File.dirname(__FILE__),"testmodel")

	include Testmodel::ClassModelChecker
    include RGen::Util::ModelComparator
	
	def test_copyTransformer
		envIn = RGen::Environment.new
		envOut = RGen::Environment.new

    EASupport.instantiateUML13FromXMI11(envIn, MODEL_DIR+"/ea_testmodel.xml") 
		
		CopyTransformer.new(envIn, envOut).transform
		checkClassModel(envOut)
		assert modelEqual?(
		  envIn.find(:class => UML13::Model).first,
		  envOut.find(:class => UML13::Model).first)
	end
	
end
