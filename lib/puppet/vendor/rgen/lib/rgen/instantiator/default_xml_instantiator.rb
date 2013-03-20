require 'rgen/instantiator/nodebased_xml_instantiator'

module RGen

module Instantiator

# A default XML instantiator.
# Derive your own instantiator from this class or use it as is.
# 
class DefaultXMLInstantiator < NodebasedXMLInstantiator
	include Util::NameHelper

	NamespaceDescriptor = Struct.new(:prefix, :target)
	
	class << self
	
		def map_tag_ns(from, to, prefix="")
			tag_ns_map[from] = NamespaceDescriptor.new(prefix, to)
		end
		
		def tag_ns_map # :nodoc:
			@tag_ns_map ||={}
			@tag_ns_map
		end
		
	end	
	
	def initialize(env, default_module, create_mm=false)
		super(env)
		@default_module = default_module
		@create_mm = create_mm
	end
		
	def on_descent(node)
		obj = new_object(node)
		@env << obj unless obj.nil?
		node.object = obj
		node.attributes.each_pair { |k,v| set_attribute(node, k, v) }
	end

	def on_ascent(node)
		node.children.each { |c| assoc_p2c(node, c) }
		node.object.class.has_attr 'chardata', Object unless node.object.respond_to?(:chardata)
		set_attribute(node, "chardata", node.chardata)
	end
	
  def class_name(str)
    saneClassName(str)
  end
  
	def new_object(node)
		ns_desc = self.class.tag_ns_map[node.namespace]
		class_name = class_name(ns_desc.nil? ? node.qtag : ns_desc.prefix+node.tag)
		mod = (ns_desc && ns_desc.target) || @default_module		
		build_on_error(NameError, :build_class, class_name, mod) do
			mod.const_get(class_name).new
		end
	end
  
	def build_class(name, mod)
		mod.const_set(name, Class.new(RGen::MetamodelBuilder::MMBase))
	end
  
  def method_name(str)
    saneMethodName(str)
  end

	def assoc_p2c(parent, child)
        return unless parent.object && child.object
        method_name = method_name(className(child.object))
		build_on_error(NoMethodError, :build_p2c_assoc, parent, child, method_name) do
			parent.object.addGeneric(method_name, child.object)
			child.object.setGeneric("parent", parent.object)
		end
	end
	
	def build_p2c_assoc(parent, child, method_name)
		parent.object.class.has_many(method_name, child.object.class)
		child.object.class.has_one("parent", RGen::MetamodelBuilder::MMBase)
	end
	
	def set_attribute(node, attr, value)
	   return unless node.object
	   	build_on_error(NoMethodError, :build_attribute, node, attr, value) do
			node.object.setGeneric(method_name(attr), value)
		end
	end
	
	def build_attribute(node, attr, value)
		node.object.class.has_attr(method_name(attr))
	end

	protected
	
	# Helper method for implementing classes.
	# This method yields the given block.
	# If the metamodel should be create automatically (see constructor)
	# rescues +error+ and calls +builder_method+ with +args+, then 
	# yields the block again.
	def build_on_error(error, builder_method, *args)
		begin
			yield
		rescue error
			if @create_mm
				send(builder_method, *args)
				yield
			else
				raise
			end
		end
	end

end

end

end
