module Puppet
    newtype(:sshkey, Puppet::Type::ParsedType) do
        @doc = "Installs and manages ssh host keys.  At this point, this type
            only knows how to install keys into /etc/ssh/ssh_known_hosts, and
            it cannot manage user authorized keys yet."

        newstate(:type) do
            desc "The encryption type used.  Probably ssh-dss or ssh-rsa."
        end

        newstate(:key) do
            desc "The key itself; generally a long string of hex digits."
        end

        # FIXME This should automagically check for aliases to the hosts, just
        # to see if we can automatically glean any aliases.
        newstate(:alias) do
            desc "Any alias the host might have.  Multiple values must be
                specified as an array.  Note that this state has the same name
                as one of the metaparams; using this state to set aliases will
                make those aliases available in your Puppet scripts."

            # We actually want to return the whole array here, not just the first
            # value.
            def should
                if defined? @should
                    return @should
                else
                    return nil
                end
            end

            validate do |value|
                if value =~ /\s/
                    raise Puppet::Error, "Aliases cannot include whitespace"
                end
                if value =~ /,/
                    raise Puppet::Error, "Aliases cannot include whitespace"
                end
            end

            # Make a puppet alias in addition.
            munge do |value|
                # Add the :alias metaparam in addition to the state
                @parent.newmetaparam(@parent.class.metaparamclass(:alias), value)
                value
            end
        end

        newparam(:name) do
            desc "The host name."

            isnamevar
        end
    end
end

# $Id$
