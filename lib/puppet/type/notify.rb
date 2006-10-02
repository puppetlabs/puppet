#
# Simple module for logging messages on the client-side
#

module Puppet
  newtype(:notify) do
    @doc = "Sends an arbitrary message to the puppetd run-time log."

    newstate(:message) do
      desc "The message to be sent to the log."
      def sync
        case @parent["withpath"]
          when :true:
            log(self.should)
          else  
            Puppet::info(self.should)
          end
        return
      end
    
      def retrieve
        return
      end
      
      def insync?
        false
      end
      
    end
    
    newparam(:withpath) do 
      desc "Whether to not to show the full object path. If true, the message 
            will be sent to the client at the current loglevel.  If false, 
            the message will be sent to the client at the info level."
      defaultto :true
      newvalues(:true, :false) 
    end
    
    newparam(:name) do
      desc "An arbitrary tag for your own reference; the name of the message."
      isnamevar
    end
  end
end

# $Id:$