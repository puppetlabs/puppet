# Test whether a given class or definition is defined
Puppet::Parser::Functions::newfunction(:defined, :type => :rvalue, :doc => "Determine whether
  a given type, class, resource, or node is defined, and return
  true or false. Accepts class names, type names, resource references, and node
  references.
  
  The `defined` function checks both native and defined types, including types
  provided as plugins via modules. Types are checked using their names:
  
      defined(\"file\")
      defined(\"customtype\")
  
  Classes are also checked using their names:
  
      defined(\"foo\")
      defined(\"foo::bar\")
  
  Unlike classes and types, resource definitions are checked using resource
  references, e.g. `defined( File['/tmp/myfile'] )`. Checking whether a given
  resource defined is, unfortunately, dependent on the parse order of the
  configuration, and the following code will not work:
  
      if defined(File['/tmp/foo']) {
          notify(\"This configuration includes the /tmp/foo file.\")
      }
      file {\"/tmp/foo\":
          ensure => present,
      }
  
  However, this order requirement refers to parse order only, and ordering of
  resources in the configuration graph (e.g. with `begin` or `require`) does not
  affect the behavior of `defined`.
  
  You can also use `defined` to check whether a node is defined using syntax
  resembling a resource reference, like `Node[\"testnode.domain.com\"]`. This usage
  is not necessarily recommended, and is included here only in the spirit of
  completeness. Checking for node definitions behaves differently from the other
  uses of `defined`: it will only return true if a definition for the specified
  node (the name of which must match exactly) exists in the manifest **AND** the
  specified node matches the node whose configuration is being compiled (either
  directly or through node inheritance). The `define` function cannot be used to
  introspect information returned by an external node classifier. ") do |vals|
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
