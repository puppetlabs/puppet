module Puppet
    newtype(:mailalias) do
        @doc = "Creates an email alias in the local alias database."

        ensurable

        newparam(:name, :namevar => true) do
            desc "The alias name."
        end

        newproperty(:recipient, :array_matching => :all) do
            desc "Where email should be sent.  Multiple values
                should be specified as an array."

            def is_to_s(value)
                if value.include?(:absent)
                    super
                else
                    value.join(",")
                end
            end

            def should
                @should
            end

            def should_to_s(value)
                if value.include?(:absent)
                    super
                else
                    value.join(",")
                end
            end
        end

        newproperty(:target) do
            desc "The file in which to store the aliases.  Only used by
                those providers that write to disk."

            defaultto { if @resource.class.defaultprovider.ancestors.include?(Puppet::Provider::ParsedFile)
                    @resource.class.defaultprovider.default_target
                else
                    nil
                end
            }
        end
    end
end

