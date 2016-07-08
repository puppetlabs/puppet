# Determines whether a given class or resource type is defined and returns a Boolean
# value. You can also use `defined` to determine whether a specific resource is defined,
# or whether a variable has a value (including `undef`, as opposed to the variable never
# being declared or assigned).
#
# This function takes at least one string argument, which can be a class name, type name,
# resource reference, or variable reference of the form `'$name'`.
#
# The `defined` function checks both native and defined types, including types
# provided by modules. Types and classes are matched by their names. The function matches
# resource declarations by using resource references.
#
# **Examples**: Different types of `defined` function matches
#
# ~~~ puppet
# # Matching resource types
# defined("file")
# defined("customtype")
#
# # Matching defines and classes
# defined("foo")
# defined("foo::bar")
#
# # Matching variables
# defined('$name')
#
# # Matching declared resources
# defined(File['/tmp/file'])
# ~~~
#
# Puppet depends on the configuration's evaluation order when checking whether a resource
# is declared.
#
# @example Importance of evaluation order when using `defined`
#
# ~~~ puppet
# # Assign values to $is_defined_before and $is_defined_after using identical `defined`
# # functions.
#
# $is_defined_before = defined(File['/tmp/file'])
#
# file { "/tmp/file":
#   ensure => present,
# }
#
# $is_defined_after = defined(File['/tmp/file'])
#
# # $is_defined_before returns false, but $is_defined_after returns true.
# ~~~
#
# This order requirement only refers to evaluation order. The order of resources in the
# configuration graph (e.g. with `before` or `require`) does not affect the `defined`
# function's behavior.
#
# > **Warning:** Avoid relying on the result of the `defined` function in modules, as you
# > might not be able to guarantee the evaluation order well enough to produce consistent
# > results. This can cause other code that relies on the function's result to behave
# > inconsistently or fail.
#
# If you pass more than one argument to `defined`, the function returns `true` if _any_
# of the arguments are defined. You can also match resources by type, allowing you to
# match conditions of different levels of specificity, such as whether a specific resource
# is of a specific data type.
#
# @example Matching multiple resources and resources by different types with `defined`
#
# ~~~ puppet
# file { "/tmp/file1":
#   ensure => file,
# }
#
# $tmp_file = file { "/tmp/file2":
#   ensure => file,
# }
#
# # Each of these statements return `true` ...
# defined(File['/tmp/file1'])
# defined(File['/tmp/file1'],File['/tmp/file2'])
# defined(File['/tmp/file1'],File['/tmp/file2'],File['/tmp/file3'])
# # ... but this returns `false`.
# defined(File['/tmp/file3'])
#
# # Each of these statements returns `true` ...
# defined(Type[Resource['file','/tmp/file2']])
# defined(Resource['file','/tmp/file2'])
# defined(File['/tmp/file2'])
# defined('$tmp_file')
# # ... but each of these returns `false`.
# defined(Type[Resource['exec','/tmp/file2']])
# defined(Resource['exec','/tmp/file2'])
# defined(File['/tmp/file3'])
# defined('$tmp_file2')
# ~~~
#
# @since 2.7.0
# @since 3.6.0 variable reference and future parser types
# @since 3.8.1 type specific requests with future parser
# @since 4.0.0
#
Puppet::Functions.create_function(:'defined', Puppet::Functions::InternalFunction) do

  dispatch :is_defined do
    scope_param
    required_repeated_param 'Variant[String, Type[CatalogEntry], Type[Type[CatalogEntry]]]', :vals
  end

  def is_defined(scope, *vals)
    env = scope.environment
    vals.any? do |val|
      case val
      when String
        if val =~ /^\$(.+)$/
          scope.exist?($1)
        else
          case val
          when ''
            next nil
          when 'main'
            # Find the main class (known as ''), it does not have to be in the catalog
            Puppet::Pops::Evaluator::Runtime3ResourceSupport.find_main_class(scope)
          else
            # Find a resource type, definition or class definition
            krt = scope.environment.known_resource_types
            Puppet::Pops::Evaluator::Runtime3ResourceSupport.find_resource_type_or_class(scope, val)
          end
        end
      when Puppet::Resource
        # Find instance of given resource type and title that is in the catalog
        scope.compiler.findresource(val.type, val.title)

      when Puppet::Pops::Types::PResourceType
        raise ArgumentError, 'The given resource type is a reference to all kind of types' if val.type_name.nil?
        if val.title.nil?
          Puppet::Pops::Evaluator::Runtime3ResourceSupport.find_resource_type(scope, val.type_name)
        else
          scope.compiler.findresource(val.type_name, val.title)
        end

      when Puppet::Pops::Types::PHostClassType
        raise  ArgumentError, 'The given class type is a reference to all classes' if val.class_name.nil?
        scope.compiler.findresource(:class, val.class_name)

      when Puppet::Pops::Types::PType
        case val.type
        when Puppet::Pops::Types::PResourceType
          # It is most reasonable to take Type[File] and Type[File[foo]] to mean the same as if not wrapped in a Type
          # Since the difference between File and File[foo] already captures the distinction of type vs instance.
          is_defined(scope, val.type)

        when Puppet::Pops::Types::PHostClassType
          # Interpreted as asking if a class (and nothing else) is defined without having to be included in the catalog
          # (this is the same as asking for just the class' name, but with the added certainty that it cannot be a defined type.
          #
          raise  ArgumentError, 'The given class type is a reference to all classes' if val.type.class_name.nil?
          Puppet::Pops::Evaluator::Runtime3ResourceSupport.find_hostclass(scope, val.type.class_name)
          #scope.environment.known_resource_types.find_hostclass(val.type.class_name)
        end
      else
        raise ArgumentError, "Invalid argument of type '#{val.class}' to 'defined'"
      end
    end
  end
end
