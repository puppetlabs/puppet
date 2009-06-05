type = Puppet::Util::Reference.newreference :type, :doc => "All Puppet resource types and all their details" do
    types = {}
    Puppet::Type.loadall

    Puppet::Type.eachtype { |type|
        next if type.name == :puppet
        next if type.name == :component
        types[type.name] = type
    }

    str = %{

Resource Types
--------------

- The *namevar* is the parameter used to uniquely identify a type instance.
  This is the parameter that gets assigned when a string is provided before
  the colon in a type declaration.  In general, only developers will need to
  worry about which parameter is the ``namevar``.

  In the following code::

      file { "/etc/passwd":
          owner => root,
          group => root,
          mode => 644
      }

  ``/etc/passwd`` is considered the title of the file object (used for things like
  dependency handling), and because ``path`` is the namevar for ``file``, that
  string is assigned to the ``path`` parameter.

- *Parameters* determine the specific configuration of the instance.  They either
  directly modify the system (internally, these are called properties) or they affect
  how the instance behaves (e.g., adding a search path for ``exec`` instances
  or determining recursion on ``file`` instances).

- *Providers* provide low-level functionality for a given resource type.  This is
  usually in the form of calling out to external commands.

  When required binaries are specified for providers, fully qualifed paths
  indicate that the binary must exist at that specific path and unqualified
  binaries indicate that Puppet will search for the binary using the shell
  path.

- *Features* are abilities that some providers might not support.  You can use the list
  of supported features to determine how a given provider can be used.

  Resource types define features they can use, and providers can be tested to see
  which features they provide.

    }

    types.sort { |a,b|
        a.to_s <=> b.to_s
    }.each { |name,type|

        str += "

----------------

"

        str += h(name, 3)
        str += scrub(type.doc) + "\n\n"

        # Handle the feature docs.
        if featuredocs = type.featuredocs
            str += h("Features", 4)
            str += featuredocs
        end

        docs = {}
        type.validproperties.sort { |a,b|
            a.to_s <=> b.to_s
        }.reject { |sname|
            property = type.propertybyname(sname)
            property.nodoc
        }.each { |sname|
            property = type.propertybyname(sname)

            unless property
                raise "Could not retrieve property %s on type %s" % [sname, type.name]
            end

            doc = nil
            unless doc = property.doc
                $stderr.puts "No docs for %s[%s]" % [type, sname]
                next
            end
            doc = doc.dup
            tmp = doc
            tmp = scrub(tmp)

            docs[sname]  = tmp
        }

        str += h("Parameters", 4) + "\n"
        type.parameters.sort { |a,b|
            a.to_s <=> b.to_s
        }.each { |name,param|
            #docs[name] = indent(scrub(type.paramdoc(name)), $tab)
            docs[name] = scrub(type.paramdoc(name))
        }

        docs.sort { |a, b|
            a[0].to_s <=> b[0].to_s
        }.each { |name, doc|
            namevar = type.namevar == name and name != :name
            str += paramwrap(name, doc, :namevar => namevar)
        }
        str += "\n"
    }

    str
end
