# Test whether a given class or definition is defined
Puppet::Parser::Functions::newfunction(:defined, :type => :rvalue, :doc => "Determine whether
  a given class or resource type is defined. This function can also determine whether a
  specific resource has been declared. Returns true or false. Accepts class names,
  type names, and resource references.

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
  affect the behavior of `defined`.") do |vals|
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
