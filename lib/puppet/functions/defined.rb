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
# `defined( File['/tmp/myfile'] )`, or `defined( Class[myclass] )`.
# Checking whether a given resource
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
# You may also search using types:
#
#     defined(Resource['file','/some/file'])
#     defined(File['/some/file'])
#     defined(Class['foo'])
#
# The `defined` function does not answer if data types (e.g. `Integer`) are defined. If
# given the string 'integer' the result is false, and if given a non CatalogEntry type,
# an error is raised.
#
# The rules for asking for undef, empty strings, and the main class are different from 3.x
# (non future parser) and 4.x (with future parser or in Puppet 4.0.0 and later):
#
#     defined('')     # 3.x => true,  4.x => false
#     defined(undef)  # 3.x => true,  4.x => error
#     defined('main') # 3.x => false, 4.x => true
#
# With the future parser, it is also possible to ask specifically if a name is
# a resource type (built in or defined), or a class, by giving its type:
#
#     defined(Type[Class['foo']])
#     defined(Type[Resource['foo']])
#
# Which is different from asking:
#
#     defined('foo')
#
# Since the later returns true if 'foo' is either a class, a built-in resource type, or a user defined
# resource type, and a specific request like `Type[Class['foo']]` only returns true if `'foo'` is a class.
#
# @since 2.7.0
# @since 3.6.0 variable reference and future parser types")
# @since 3.8.1 type specific requests with future parser
#
Puppet::Functions.create_function(:'defined', Puppet::Functions::InternalFunction) do

  dispatch :is_defined do
    scope_param
    required_repeated_param 'Variant[String, Type[CatalogEntry], Type[Type[CatalogEntry]]]', :vals
  end

  def is_defined(scope, *vals)
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
            scope.find_hostclass('')
          else
            # Find a resource type, definition or class definition
            scope.find_resource_type(val) || scope.find_definition(val) || scope.find_hostclass(val)
            #scope.compiler.findresource(:class, val)
          end
        end
      when Puppet::Resource
        # Find instance of given resource type and title that is in the catalog
        scope.compiler.findresource(val.type, val.title)

      when Puppet::Pops::Types::PResourceType
        raise ArgumentError, 'The given resource type is a reference to all kind of types' if val.type_name.nil?
        if val.title.nil?
          scope.find_builtin_resource_type(val.type_name) || scope.find_definition(val.type_name)
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
          scope.find_hostclass(val.type.class_name)
        end
      else
        raise ArgumentError, "Invalid argument of type '#{val.class}' to 'defined'"
      end
    end
  end
end
