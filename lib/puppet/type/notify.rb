#
# Simple module for logging messages on the client-side
#

module Puppet
    newtype(:notify) do
        @doc = "Sends an arbitrary message to the puppetd run-time log."

        newproperty(:message) do
            desc "The message to be sent to the log."
            def sync
                case @parent["withpath"]
                when :true:
                    log(self.should)
                else  
                    Puppet.send(@parent[:loglevel], self.should)
                end
                return
            end

            def retrieve
                return
            end

            def insync?(is)
                false
            end

            defaultto { @parent[:name] }
        end

        newparam(:withpath) do 
            desc "Whether to not to show the full object path.  Sends the
                message at the current loglevel."
            defaultto :false

            newvalues(:true, :false) 
        end

        newparam(:name) do
            desc "An arbitrary tag for your own reference; the name of the message."
            isnamevar
        end
    end
end

# $Id$
