require 'rgen/metamodel_builder'

module Puppet::Pops
module Types
# The ClassLoader provides a Class instance given a class name or a meta-type.
# If the class is not already loaded, it is loaded using the Puppet Autoloader.
# This means it can load a class from a gem, or from puppet modules.
#
class ClassLoader
  @autoloader = Puppet::Util::Autoload.new("ClassLoader", "")

  # Returns a Class given a fully qualified class name.
  # Lookup of class is never relative to the calling namespace.
  # @param name [String, Array<String>, Array<Symbol>, PAnyType] A fully qualified
  #   class name String (e.g. '::Foo::Bar', 'Foo::Bar'), a PAnyType, or a fully qualified name in Array form where each part
  #   is either a String or a Symbol, e.g. `%w{Puppetx Puppetlabs SomeExtension}`.
  # @return [Class, nil] the looked up class or nil if no such class is loaded
  # @raise ArgumentError If the given argument has the wrong type
  # @api public
  #
  def self.provide(name)
    case name
    when String
      provide_from_string(name)

    when Array
      provide_from_name_path(name.join('::'), name)

    when PAnyType, PType
      provide_from_type(name)

    else
      raise ArgumentError, "Cannot provide a class from a '#{name.class.name}'"
    end
  end

  private

  def self.provide_from_type(type)
    case type
    when PRuntimeType
      raise ArgumentError.new("Only Runtime type 'ruby' is supported, got #{type.runtime}") unless type.runtime == :ruby
      provide_from_string(type.runtime_type_name)

    when PBooleanType
      # There is no other thing to load except this Enum meta type
      RGen::MetamodelBuilder::MMBase::Boolean

    when PType
      # TODO: PType should has a type argument (a PAnyType) so the Class' class could be returned
      #       (but this only matters in special circumstances when meta programming has been used).
      Class

    when POptionalType
      # cannot make a distinction between optional and its type
      provide_from_type(type.optional_type)

    # Although not expected to be the first choice for getting a concrete class for these
    # types, these are of value if the calling logic just has a reference to type.
    #
    when PArrayType    ; Array
    when PTupleType    ; Array
    when PHashType     ; Hash
    when PStructType   ; Hash
    when PRegexpType   ; Regexp
    when PIntegerType  ; Integer
    when PStringType   ; String
    when PPatternType  ; String
    when PEnumType     ; String
    when PFloatType    ; Float
    when PUndefType      ; NilClass
    when PCallableType ; Proc
    else
      nil
    end
  end

  def self.provide_from_string(name)
    name_path = name.split(TypeFormatter::NAME_SEGMENT_SEPARATOR)
    # always from the root, so remove an empty first segment
    name_path.shift if name_path[0].empty?
    provide_from_name_path(name, name_path)
  end

  def self.provide_from_name_path(name, name_path)
    # If class is already loaded, try this first
    result = find_class(name_path)

    unless result.is_a?(Class)
      # Attempt to load it using the auto loader
      loaded_path = nil
      if paths_for_name(name_path).find {|path| loaded_path = path; @autoloader.load(path, Puppet.lookup(:current_environment)) }
        result = find_class(name_path)
        unless result.is_a?(Class)
          raise RuntimeError, "Loading of #{name} using relative path: '#{loaded_path}' did not create expected class"
        end
      end
    end
    return nil unless result.is_a?(Class)
    result
  end

  def self.find_class(name_path)
    name_path.reduce(Object) do |ns, name|
      begin
        ns.const_get(name)
      rescue NameError
        return nil
      end
    end
  end

  def self.paths_for_name(fq_named_parts)
    # search two entries, one where all parts are decamelized, and one with names just downcased
    # TODO:this is not perfect - it will not produce the correct mix if a mix of styles are used
    # The alternative is to test many additional paths.
    #
    [fq_named_parts.map {|part| de_camel(part)}.join('/'), fq_named_parts.join('/').downcase ]
  end

  def self.de_camel(fq_name)
    fq_name.to_s.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end

end
end
end
