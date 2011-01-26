# Test whether a given class or definition is defined
Puppet::Parser::Functions::newfunction(:defined, :type => :rvalue, :doc => "Determine whether
  a given type or class is defined. This function can also determine whether a
  specific resource has been declared. Returns true or false. Accepts class names,
  type names, resource references, and node references.

  The `defined` function checks both native and defined types, including types
  provided as plugins via modules. Types and classes are both checked using their names:

      defined(\"file\")
      defined(\"customtype\")
      defined(\"foo\")
      defined(\"foo::bar\")

  Resource declarations are checked using resource references, e.g.
  `defined( File['/tmp/myfile'] )`. Checking whether a given resource
  has been declared is, unfortunately, dependent on the parse order of
  the configuration, and the following code will not work:

      if defined(File['/tmp/foo']) {
          notify(\"This configuration includes the /tmp/foo file.\")
      }
      file {\"/tmp/foo\":
          ensure => present,
      }

  However, this order requirement refers to parse order only, and ordering of
  resources in the configuration graph (e.g. with `before` or `require`) does not
  affect the behavior of `defined`.

  You can also use `defined` to check whether a node is declared using syntax
  resembling a resource reference, like `Node[\"testnode.domain.com\"]`. This usage
  is not necessarily recommended, and is included here only in the spirit of
  completeness. Note that:

  * Only the node whose configuration is being compiled is considered declared;
  the `define` function will not return information about definitions not currently
  being used.
  * Node definitions inherited by the current node are considered declared;
  however, the default node is never considered declared.
  * A node is not considered declared simply by virtue of receiving a
  configuration; it must have matched a node definition in the manifest.
  * The name used in the node reference must match the name used in the node
  definition, even if this is not the node's actual certname.
  * Regular expression node definitions cannot be checked for declaration using
  `define`, nor can `define` be used to introspect information returned by an
  external node classifier.") do |vals|
    result = false
    vals = [vals] unless vals.is_a?(Array)
    vals.each do |val|
      case val
      when String
        if Puppet::Type.type(val) or find_definition(val) or find_hostclass(val)
          result = true
          break
        end
      when Puppet::Resource
        if findresource(val.to_s)
          result = true
          break
        end
      else
        raise ArgumentError, "Invalid argument of type '#{val.class}' to 'defined'"
      end
    end
    result
end
