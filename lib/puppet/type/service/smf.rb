# Solaris 10 SMF-style services.  This is not yet implemented, which is probably
# somewhat obvious.
Puppet.type(:service).newsvctype(:smf) do
    def restartcmd
    end

    # The start command is just the init scriptwith 'start'.
    def startcmd
        self.initscript + " start"
    end

    # If it was specified that the init script has a 'status' command, then
    # we just return that; otherwise, we return false, which causes it to
    # fallback to other mechanisms.
    def statuscmd
        if self[:hasstatus]
            return self.initscript + " status"
        else
            return false
        end
    end

    # The stop command is just the init script with 'stop'.
    def stopcmd
        self.initscript + " stop"
    end
end

# $Id$
