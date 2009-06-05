metaparameter = Puppet::Util::Reference.newreference :metaparameter, :doc => "All Puppet metaparameters and all their details" do
    types = {}
    Puppet::Type.loadall

    Puppet::Type.eachtype { |type|
        next if type.name == :puppet
        next if type.name == :component
        types[type.name] = type
    }

   str = %{
Metaparameters
--------------
Metaparameters are parameters that work with any resource type; they are part of the
Puppet framework itself rather than being part of the implementation of any
given instance.  Thus, any defined metaparameter can be used with any instance
in your manifest, including defined components.

Available Metaparameters
++++++++++++++++++++++++
}
    begin
        params = []
        Puppet::Type.eachmetaparam { |param|
            params << param
        }

        params.sort { |a,b|
            a.to_s <=> b.to_s
        }.each { |param|
            str += paramwrap(param.to_s, scrub(Puppet::Type.metaparamdoc(param)), :level => 4)
            #puts "<dt>" + param.to_s + "</dt>"
            #puts tab(1) + Puppet::Type.metaparamdoc(param).scrub.indent($tab)gsub(/\n\s*/,' ')
            #puts "<dd>"
            #puts indent(scrub(Puppet::Type.metaparamdoc(param)), $tab)
            #puts scrub(Puppet::Type.metaparamdoc(param))
            #puts "</dd>"

            #puts ""
        }
    rescue => detail
        puts detail.backtrace
        puts "incorrect metaparams: %s" % detail
        exit(1)
    end

    str
end
