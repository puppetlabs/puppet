# RGen Framework
# (c) Martin Thiede, 2006

require 'rgen/metamodel_builder'

module RGen

module Util

class Base
	extend MetamodelBuilder
	def initialize(env=nil)
		env << self if env
	end
end

class AutoCreatedClass < Base
	def method_missing(m,*args)
		return super unless self.class.parent.accEnabled
		if m.to_s =~ /(.*)=$/ 
			self.class.has_one($1)
			send(m,args[0])
		elsif args.size == 0
			self.class.has_many(m)
			send(m)
		end
	end
end

# will be "extended" to the auto created class
module ParentAccess
	def parent=(p)
		@parent = p
	end
	def parent
		@parent
	end
end

module AutoClassCreator
	attr_reader :accEnabled
	def const_missing(className)
		return super unless @accEnabled
		module_eval("class "+className.to_s+" < RGen::AutoCreatedClass; end")
		c = const_get(className)
		c.extend(ParentAccess)
		c.parent = self
		c
	end
	def enableACC
		@accEnabled = true
	end
	def disableACC
		@accEnabled = false
	end
end

end

end

