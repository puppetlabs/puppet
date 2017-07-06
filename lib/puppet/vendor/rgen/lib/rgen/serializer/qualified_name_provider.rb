module RGen

module Serializer

# simple identifier calculation based on qualified names.
# as a prerequisit, elements must have a local name stored in single attribute +attribute_name+.
# there may be classes without the name attribute though and there may be elements without a
# local name. in both cases the element will have the same qualified name as its container.
#
class QualifiedNameProvider

  def initialize(options={})
    @qualified_name_cache = {}
    @attribute_name = options[:attribute_name] || "name"
    @separator = options[:separator] || "/"
    @leading_separator = options.has_key?(:leading_separator) ? options[:leading_separator] : true 
  end

  def identifier(element)
    if element.is_a?(RGen::MetamodelBuilder::MMProxy) 
      element.targetIdentifier
    else
      qualified_name(element)
    end
  end

  def qualified_name(element)
    return @qualified_name_cache[element] if @qualified_name_cache[element]
    local_ident = ((element.respond_to?(@attribute_name) && element.getGeneric(@attribute_name)) || "").strip
    parent = element.eContainer
    if parent
      if local_ident.size > 0
        result = qualified_name(parent) + @separator + local_ident
      else
        result = qualified_name(parent)
      end
    else
      result = (@leading_separator ? @separator : "") + local_ident
    end
    @qualified_name_cache[element] = result
  end
end

end

end

