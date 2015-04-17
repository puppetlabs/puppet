# Determines whether
# a given class or resource type is defined. This function can also determine whether a
# specific resource has been declared, or whether a variable has been assigned a value
# (including undef...as opposed to never having been assigned anything). Returns true
# or false. Accepts class names, type names, resource references, and variable
# reference strings of the form '$name'.  When more than one argument is
# supplied, defined() returns true if any are defined.
#
# The `defined` function checks both native and defined types, including types
# provided as plugins via modules. Types and classes are both checked using their names:
#
#     defined("file")
#     defined("customtype")
#     defined("foo")
#     defined("foo::bar")
#     defined('$name')
#
# Resource declarations are checked using resource references, e.g.
# `defined( File['/tmp/myfile'] )`. Checking whether a given resource
# has been declared is, unfortunately, dependent on the evaluation order of
# the configuration, and the following code will not work:
#
#     if defined(File['/tmp/foo']) {
#         notify { "This configuration includes the /tmp/foo file.":}
#     }
#     file { "/tmp/foo":
#         ensure => present,
#     }
#
# However, this order requirement refers to evaluation order only, and ordering of
# resources in the configuration graph (e.g. with `before` or `require`) does not
# affect the behavior of `defined`.
#
# If the future parser is in effect, you may also search using types:
#
#     defined(Resource['file','/some/file'])
#     defined(File['/some/file'])
#     defined(Class['foo'])
#
# When used with the future parser (4.x), the `defined` function does not answer if data
# types (e.g. `Integer`) are defined, and the rules for asking for undef, empty strings, and
# the main class are different:
#
#     defined('')     # 3.x => true,  4.x => false
#     defined(undef)  # 3.x => true,  4.x => error
#     defined('main') # 3.x => false, 4.x => true
#
# @since 2.7.0
# @since 3.6.0 variable reference and future parser types")
#
Puppet::Functions.create_function(:'defined', Puppet::Functions::InternalFunction) do

  ARG_TYPE = 'Variant[String,Type[CatalogEntry]]'

  dispatch :is_defined do
    scope_param
    param          ARG_TYPE, 'first_arg'
    repeated_param ARG_TYPE, 'additional_args'
  end

  def is_defined(scope, *vals)
    vals.any? do |val|
      case val
      when String
        if m = /^\$(.+)$/.match(val)
          scope.exist?(m[1])
        else
          val = case val
          when ''
            next nil
          when 'main'
            ''
          else
            val
          end
          scope.find_resource_type(val) || scope.find_definition(val) || scope.find_hostclass(val)
        end
      when Puppet::Resource
        scope.compiler.findresource(val.type, val.title)

      when Puppet::Pops::Types::PResourceType
        raise ArgumentError, "The given resource type is a reference to all kind of types" if val.type_name.nil?
        if val.title.nil?
          scope.find_builtin_resource_type(val.type_name) || scope.find_definition(val.type_name)
        else
          scope.compiler.findresource(val.type_name, val.title)
        end

      when Puppet::Pops::Types::PHostClassType
        raise  ArgumentError, "The given class type is a reference to all classes" if val.class_name.nil?
        scope.find_hostclass(val.class_name)

      else
        raise ArgumentError, "Invalid argument of type '#{val.class}' to 'defined'"
      end
    end
  end
end
