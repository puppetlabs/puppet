#
# Simple module for logging messages on the client-side
#

module Puppet
  newtype(:notify) do
    @doc = "Sends an arbitrary message to the puppetd run-time log."

    #
    # This state
    #
    newstate(:message) do
      desc "The message to be sent to the log."
      def sync
        Puppet::info(self.should)
        return
      end
    
      def retrieve
        return
      end
      
      def insync?
        false
      end
      
    end
    
    newparam(:name) do
      desc "An arbitrary reference tag; the name of the message."
      isnamevar
    end
    
  end
end

# $Id:$