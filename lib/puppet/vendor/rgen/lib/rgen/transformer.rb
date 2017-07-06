require 'rgen/ecore/ecore'
require 'rgen/ecore/ecore_ext'

module RGen

# The Transformer class can be used to specify model transformations.
# 
# Model transformations take place between a <i>source model</i> (located in the <i>source
# environment</i> being an instance of the <i>source metamodel</i>) and a <i>target model</i> (located
# in the <i>target environment</i> being an instance of the <i>target metamodel</i>).
# Normally a "model" consists of several model elements associated with each other.
# 
# =Transformation Rules
# 
# The transformation is specified within a subclass of Transformer.
# Within the subclass, the Transformer.transform class method can be used to specify transformation
# blocks for specific metamodel classes of the source metamodel.
# 
# If there is no transformation rule for the current object's class, a rule for the superclass
# is used instead. If there's no rule for the superclass, the class hierarchy is searched
# this way until Object.
# 
# Here is an example:
# 
# 	class MyTransformer < RGen::Transformer
# 
# 		transform InputClass, :to => OutputClass do
# 			{ :name => name, :otherClass => trans(otherClass) }
# 		end
# 
# 		transform OtherInputClass, :to => OtherOutputClass do
# 			{ :name => name }
# 		end
# 	end
# 
# In this example a transformation rule is specified for model elements of class InputClass
# as well as for elements of class OtherInputClass. The former is to be transformed into
# an instance of OutputClass, the latter into an instance of OtherOutputClass.
# Note that the Ruby class objects are used to specifiy the classes.
#
# =Transforming Attributes
# 
# Besides the target class of a transformation, the attributes of the result object are
# specified in the above example. This is done by providing a Ruby block with the call of
# +transform+. Within this block arbitrary Ruby code may be placed, however the block
# must return a hash. This hash object specifies the attribute assignment of the
# result object using key/value pairs: The key must be a Symbol specifying the attribute
# which is to be assigned by name, the value is the value that will be assigned.
#
# For convenience, the transformation block will be evaluated in the context of the
# source model element which is currently being converted. This way it is possible to just
# write <code>:name => name</code> in the example in order to assign the name of the source 
# object to the name attribute of the target object.
# 
# =Transforming References
# 
# When attributes of elements are references to other elements, those referenced
# elements have to be transformed as well. As shown above, this can be done by calling
# the Transformer#trans method. This method initiates a transformation of the element
# or array of elements passed as parameter according to transformation rules specified
# using +transform+. In fact the +trans+ method is the only way to start the transformation
# at all.
#
# For convenience and performance reasons, the result of +trans+ is cached with respect
# to the parameter object. I.e. calling trans on the same source object a second time will 
# return the same result object _without_ a second evaluation of the corresponding 
# transformation rules.
# 
# This way the +trans+ method can be used to lookup the target element for some source
# element without the need to locally store a reference to the target element. In addition
# this can be useful if it is not clear if certain element has already been transformed
# when it is required within some other transformation block. See example below.
# 
# Special care has been taken to allow the transformation of elements which reference 
# each other cyclically. The key issue here is that the target element of some transformation
# is created _before_ the transformation's block is evaluated, i.e before the elements 
# attributes are set. Otherwise a call to +trans+ within the transformation's block
# could lead to a +trans+ of the element itself.
# 
# Here is an example:
# 
# 	transform ModelAIn, :to => ModelAOut do
# 		{ :name => name, :modelB => trans(modelB) }
# 	end
# 	
# 	transform ModelBIn, :to => ModelBOut do
# 		{ :name => name, :modelA => trans(modelA) }
# 	end
#
# Note that in this case it does not matter if the transformation is initiated by calling
# +trans+ with a ModelAIn element or ModelBIn element due to the caching feature described
# above.
# 
# =Transformer Methods
# 
# When code in transformer blocks becomes more complex it might be useful to refactor
# it into smaller methods. If regular Ruby methods within the Transformer subclass are
# used for this purpose, it is necessary to know the source element being transformed.
# This could be achieved by explicitly passing the +@current_object+ as parameter of the
# method (see Transformer#trans).
# 
# A more convenient way however is to define a special kind of method using the
# Transformer.method class method. Those methods are evaluated within the context of the
# current source element being transformed just the same as transformer blocks are.
# 
# Here is an example:
# 
# 	transform ModelIn, :to => ModelOut do
# 		{ :number => doubleNumber }
# 	end
#
# 	method :doubleNumber do
# 		number * 2;
# 	end
#
# In this example the transformation assigns the 'number' attribute of the source element
# multiplied by 2 to the target element. The multiplication is done in a dedicated method
# called 'doubleNumber'. Note that the 'number' attribute of the source element is 
# accessed without an explicit reference to the source element as the method's body
# evaluates in the source element's context.
# 
# =Conditional Transformations
# 
# Using the transformations as described above, all elements of the same class are
# transformed the same way. Conditional transformations allow to transform elements of
# the same class into elements of different target classes as well as applying different
# transformations on the attributes.
# 
# Conditional transformations are defined by specifying multiple transformer blocks for
# the same source class and providing a condition with each block. Since it is important
# to create the target object before evaluation of the transformation block (see above),
# the conditions must also be evaluated separately _before_ the transformer block.
# 
# Conditions are specified using transformer methods as described above. If the return
# value is true, the corresponding block is used for transformation. If more than one
# conditions are true, only the first transformer block will be evaluated.
# 
# If there is no rule with a condition evaluating to true, rules for superclasses will
# be checked as described above.
# 
# Here is an example:
# 
# 	transform ModelIn, :to => ModelOut, :if => :largeNumber do
# 		{ :number => number * 2}
# 	end
#
# 	transform ModelIn, :to => ModelOut, :if => :smallNumber do
# 		{ :number => number / 2 }
# 	end
# 	
# 	method :largeNumber do
# 		number > 1000
# 	end
# 	
# 	method :smallNumber do
# 		number < 500
# 	end
# 
# In this case the transformation of an element of class ModelIn depends on the value
# of the element's 'number' attribute. If the value is greater than 1000, the first rule
# as taken and the number is doubled. If the value is smaller than 500, the second rule
# is taken and the number is divided by two.
# 
# Note that it is up to the user to avoid cycles within the conditions. A cycle could
# occure if the condition are based on transformation target elements, i.e. if +trans+
# is used within the condition to lookup or transform other elements.
# 
# = Copy Transformations
# 
# In some cases, transformations should just copy a model, either in the same metamodel
# or in another metamodel with the same package/class structure. Sometimes, a transformation
# is not exactly a copy, but a copy with slight modifications. Also in this case most
# classes need to be copied verbatim.
#
# The class method Transformer.copy can be used to specify a copy rule for a single
# metamodel class. If no target class is specified using the :to named parameter, the
# target class will be the same as the source class (i.e. in the same metamodel).
#
#   copy MM1::ClassA                          # copy within the same metamodel
#   copy MM1::ClassA, :to => MM2::ClassA
#
# The class method Transfomer.copy_all can be used to specify copy rules for all classes
# of a particular metamodel package. Again with :to, the target metamodel package may
# be specified which must have the same package/class structure. If :to is omitted, the
# target metamodel is the same as the source metamodel. In case that for some classes
# specific transformation rules should be used instead of copy rules, exceptions may be 
# specified using the :except named parameter. +copy_all+ also provides an easy way to
# copy (clone) a model within the same metamodel.
#
#   copy_all MM1                              # copy rules for the whole metamodel MM1, 
#                                             # used to clone models of MM1
#                                          
#   copy_all MM1, :to => MM2, :except => %w(  # copy rules for all classes of MM1 to
#     ClassA                                  # equally named classes in MM2, except
#     Sub1::ClassB                            # "ClassA" and "Sub1::ClassB"
#   )
#
# If a specific class transformation is not an exact copy, the Transformer.transform method
# should be used to actually specify the transformation. If this transformation is also
# mostly a copy, the helper method Transformer#copy_features can be used to create the
# transformation Hash required by the transform method. Any changes to this hash may be done
# in a hash returned by a block given to +copy_features+. This hash will extend or overwrite
# the default copy hash. In case a particular feature should not be part of the copy hash
# (e.g. because it does not exist in the target metamodel), exceptions can be specified using
# the :except named parameter. Here is an example:
#
#   transform ClassA, :to => ClassAx do
#     copy_features :except => [:featA] do 
#       { :featB => featA }
#     end
#   end
#
# In this example, ClassAx is a copy of ClassA except, that feature "featA" in ClassA is renamed
# into "featB" in ClassAx. Using +copy_features+ all features are copied except "featA". Then
# "featB" of the target class is assigned the value of "featA" of the source class.
#
class Transformer
	
	TransformationDescription = Struct.new(:block, :target) # :nodoc:
	
	@@methods = {}
	@@transformer_blocks = {}

	def self._transformer_blocks # :nodoc:
		@@transformer_blocks[self] ||= {}
	end

	def self._methods # :nodoc:
		@@methods[self] ||= {}
	end
	
	# This class method is used to specify a transformation rule.
	#
	# The first argument specifies the class of elements for which this rule applies.
	# The second argument must be a hash including the target class
	# (as value of key ':to') and an optional condition (as value of key ':if').
	# 
	# The target class is specified by passing the actual Ruby class object.
	# The condition is either the name of a transformer method (see Transfomer.method) as
	# a symbol or a proc object. In either case the block is evaluated at transformation
	# time and its result value determines if the rule applies.
	# 
	def self.transform(from, desc=nil, &block)
		to = (desc && desc.is_a?(Hash) && desc[:to])
		condition = (desc && desc.is_a?(Hash) && desc[:if])
		raise StandardError.new("No transformation target specified.") unless to
		block_desc = TransformationDescription.new(block, to)
		if condition
			_transformer_blocks[from] ||= {}
			raise StandardError.new("Multiple (non-conditional) transformations for class #{from.name}.") unless _transformer_blocks[from].is_a?(Hash)
			_transformer_blocks[from][condition] = block_desc
		else
			raise StandardError.new("Multiple (non-conditional) transformations for class #{from.name}.") unless _transformer_blocks[from].nil?
			_transformer_blocks[from] = block_desc
		end
	end

	# This class method specifies that all objects of class +from+ are to be copied
	# into an object of class +to+. If +to+ is omitted, +from+ is used as target class.
  # The target class may also be specified using the :to => <class> hash notation. 
	# During copy, all attributes and references of the target object
	# are set to their transformed counterparts of the source object.
	# 
	def self.copy(from, to=nil)
    raise StandardError.new("Specify target class either directly as second parameter or using :to => <class>") \
      unless to.nil? || to.is_a?(Class) || (to.is_a?(Hash) && to[:to].is_a?(Class))
    to = to[:to] if to.is_a?(Hash) 
		transform(from, :to => to || from) do
      copy_features
		end
  end

  # Create copy rules for all classes of metamodel package (module) +from+ and its subpackages.
  # The target classes are the classes with the same name in the metamodel package
  # specified using named parameter :to. If no target metamodel is specified, source
  # and target classes will be the same.
  # The named parameter :except can be used to specify classes by qualified name for which 
  # no copy rules should be created. Qualified names are relative to the metamodel package
  # specified.
  #
  def self.copy_all(from, hash={})
    to = hash[:to] || from
    except = hash[:except]
    fromDepth = from.ecore.qualifiedName.split("::").size
    from.ecore.eAllClasses.each do |c|
      path = c.qualifiedName.split("::")[fromDepth..-1]
      next if except && except.include?(path.join("::"))
      copy c.instanceClass, :to => path.inject(to){|m,c| m.const_get(c)}
    end
  end
	
	# Define a transformer method for the current transformer class.
	# In contrast to regular Ruby methods, a method defined this way executes in the
	# context of the object currently being transformed.
	# 
	def self.method(name, &block)
		_methods[name.to_s] = block
	end
	

	# Creates a new transformer
	# Optionally an input and output Environment can be specified.
  # If an elementMap is provided (normally a Hash) this map will be used to lookup 
  # and store transformation results. This way results can be predefined
  # and it is possible to have several transformers work on the same result map.
	# 
	def initialize(env_in=nil, env_out=nil, elementMap=nil)
		@env_in = env_in
		@env_out = env_out
		@transformer_results = elementMap || {}
		@transformer_jobs = []
	end


	# Transforms a given model element according to the rules specified by means of
	# the Transformer.transform	class method.
	# 
	# The transformation result element is created in the output environment and returned.
	# In addition, the result is cached, i.e. a second invocation with the same parameter
	# object will return the same result object without any further evaluation of the 
	# transformation rules. Nil will be transformed into nil. Ruby "singleton" objects
	# +true+, +false+, numerics and symbols will be returned without any change. Ruby strings
	# will be duplicated with the result being cached.
	# 
	# The transformation input can be given as:
	# * a single object
	# * an array each element of which is transformed in turn
	# * a hash used as input to Environment#find with the result being transformed
	# 
	def trans(obj)
		if obj.is_a?(Hash)
			raise StandardError.new("No input environment available to find model element.") unless @env_in
			obj = @env_in.find(obj) 
		end
		return nil if obj.nil?
		return obj if obj.is_a?(TrueClass) or obj.is_a?(FalseClass) or obj.is_a?(Numeric) or obj.is_a?(Symbol)
		return @transformer_results[obj] if @transformer_results[obj]
		return @transformer_results[obj] = obj.dup if obj.is_a?(String)
		return obj.collect{|o| trans(o)}.compact if obj.is_a? Array
		raise StandardError.new("No transformer for class #{obj.class.name}") unless _transformerBlock(obj.class)
		block_desc = _evaluateCondition(obj)
		return nil unless block_desc
		@transformer_results[obj] = _instantiateTargetClass(obj, block_desc.target)
		# we will transform the properties later
		@transformer_jobs << TransformerJob.new(self, obj, block_desc)
		# if there have been jobs in the queue before, don't process them in this call
		# this way calls to trans are not nested; a recursive implementation 
		# may cause a "Stack level too deep" exception for large models
		return @transformer_results[obj] if @transformer_jobs.size > 1
		# otherwise this is the first call of trans, process all jobs here
		# more jobs will be added during job execution
		while @transformer_jobs.size > 0
			@transformer_jobs.first.execute
			@transformer_jobs.shift
		end
		@transformer_results[obj]
	end
	
  # Create the hash required as return value of the block given to the Transformer.transform method.
  # The hash will assign feature values of the source class to the features of the target class,
  # assuming the features of both classes are the same. If the :except named parameter specifies
  # an Array of symbols, the listed features are not copied by the hash. In order to easily manipulate
  # the resulting hash, a block may be given which should also return a feature assignmet hash. This
  # hash should be created manually and will extend/overwrite the automatically created hash.
  #
  def copy_features(options={})
    hash = {}
    @current_object.class.ecore.eAllStructuralFeatures.each do |f|
      next if f.derived
      next if options[:except] && options[:except].include?(f.name.to_sym)
      hash[f.name.to_sym] = trans(@current_object.send(f.name))
    end
    hash.merge!(yield) if block_given?
    hash
  end
  
	def _transformProperties(obj, block_desc) #:nodoc:
		old_object, @current_object = @current_object, obj
		block_result = instance_eval(&block_desc.block)
		raise StandardError.new("Transformer must return a hash") unless block_result.is_a? Hash
		@current_object = old_object
		_attributesFromHash(@transformer_results[obj], block_result)
	end
	
	class TransformerJob #:nodoc:
		def initialize(transformer, obj, block_desc)
			@transformer, @obj, @block_desc = transformer, obj, block_desc
		end
		def execute
			@transformer._transformProperties(@obj, @block_desc)
		end
	end

	# Each call which is not handled by the transformer object is passed to the object
	# currently being transformed.
	# If that object also does not respond to the call, it is treated as a transformer
	# method call (see Transformer.method).
	# 
	def method_missing(m, *args) #:nodoc:
		if @current_object.respond_to?(m)
			@current_object.send(m, *args)
		else
			_invokeMethod(m, *args)
		end
	end

	private
	
	# returns _transformer_blocks content for clazz or one of its superclasses 
	def _transformerBlock(clazz) # :nodoc:
		block = self.class._transformer_blocks[clazz]
		block = _transformerBlock(clazz.superclass) if block.nil? && clazz != Object
		block
	end
		
	# returns the first TransformationDescription for clazz or one of its superclasses
	# for which condition is true 
	def _evaluateCondition(obj, clazz=obj.class) # :nodoc:
		tb = self.class._transformer_blocks[clazz]
		block_description = nil
		if tb.is_a?(TransformationDescription)
			# non-conditional
			block_description = tb
		elsif tb
			old_object, @current_object = @current_object, obj
			tb.each_pair {|condition, block|
				if condition.is_a?(Proc)
					result = instance_eval(&condition)
				elsif condition.is_a?(Symbol)
					result = _invokeMethod(condition)
				else
					result = condition
				end
				if result
					block_description = block 
					break
				end
			}
			@current_object = old_object
		end
		block_description = _evaluateCondition(obj, clazz.superclass) if block_description.nil? && clazz != Object
		block_description
	end
	
	def _instantiateTargetClass(obj, target_desc) # :nodoc:
		old_object, @current_object = @current_object, obj
		if target_desc.is_a?(Proc)
			target_class = instance_eval(&target_desc)
		elsif target_desc.is_a?(Symbol)
			target_class = _invokeMethod(target_desc)
		else
			target_class = target_desc
		end
		@current_object = old_object
		result = target_class.new
		@env_out << result if @env_out
		result
	end
	
	def _invokeMethod(m) # :nodoc:
			raise StandardError.new("Method not found: #{m}") unless self.class._methods[m.to_s]
			instance_eval(&self.class._methods[m.to_s])
	end
		
	def _attributesFromHash(obj, hash) # :nodoc:
		hash.delete(:class)
		hash.each_pair{|k,v|
			obj.send("#{k}=", v)
		}
		obj
	end
	
end

end