module RGen

module Instantiator

class AbstractInstantiator

	ResolverDescription = Struct.new(:from, :attribute, :block) # :nodoc:

	class << self
		attr_accessor :resolver_descs
	end

	def initialize(env)
		@env = env
	end

	# Specifies that +attribute+ should be resolved. If +:class+ is specified, 
	# resolve +attribute+ only for objects of type class.
	# The block must return the value to which the attribute should be assigned.
	# The object for which the attribute is to be resolved will be accessible
	# in the current context within the block.
	# 
	def self.resolve(attribute, desc=nil, &block)
		from = (desc.is_a?(Hash) && desc[:class])
		self.resolver_descs ||= []
		self.resolver_descs << ResolverDescription.new(from, attribute, block)
	end
	
	# Resolves +attribute+ to a model element which has attribute +:id+ set to the
	# value currently in attribute +:src+
	# 
	def self.resolve_by_id(attribute, desc)
		id_attr = (desc.is_a?(Hash) && desc[:id])
		src_attr = (desc.is_a?(Hash) && desc[:src])
		raise StandardError.new("No id attribute given.") unless id_attr
		resolve(attribute) do
			@env.find(id_attr => @current_object.send(src_attr)).first
		end
	end
	
	private
	
	def method_missing(m, *args) #:nodoc:
		if @current_object
			@current_object.send(m)
		else
			super
		end
	end
	
	def resolve
		self.class.resolver_descs ||= []
		self.class.resolver_descs.each { |desc|
			@env.find(:class => desc.from).each { |e|
				old_object, @current_object = @current_object, e
				e.send("#{desc.attribute}=", instance_eval(&desc.block)) if e.respond_to?("#{desc.attribute}=")
				@current_object = old_object
			}
		}
	end			
	
end

end

end