#
# Simple module for logging messages on the client-side
#

module Puppet
    newtype(:notify) do
        @doc = "Sends an arbitrary message to the puppetd run-time log."

        newproperty(:message) do
            desc "The message to be sent to the log."
            def sync
                case @resource["withpath"]
                when :true
                    send(@resource[:loglevel], self.should)
                else
                    Puppet.send(@resource[:loglevel], self.should)
                end
                return
            end

            def retrieve
                return
            end

            def insync?(is)
                false
            end

            defaultto { @resource[:name] }
        end

        newparam(:withpath) do
            desc "Whether to not to show the full object path."
            defaultto :false

            newvalues(:true, :false)
        end

        newparam(:name) do
            desc "An arbitrary tag for your own reference; the name of the message."
            isnamevar
        end
    end
end

