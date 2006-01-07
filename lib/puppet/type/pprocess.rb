# DISABLED
# I'm only working on services, not processes, right now

module Puppet
    class State
        class PProcessRunning < State
            @doc = "Whether a process should be running.  **true**/*false*"
            def retrieve
                running = 0
                regex = Regexp.new(@params[:pattern])
                begin
                    # this ps is only tested on Solaris
                    # XXX yeah, this definitely needs to be fixed...
                    %x{ps -ef -U #{@params[:user]}}.split("\n").each { |process|
                        if regex.match(process)
                            running += 1
                        end
                    }
                rescue
                    # this isn't correct, but what the hell
                    Puppet::Message.new(
                        :level => :error,
                        :source => self.parent,
                        :message => "Failed to run ps"
                    )
                end

                self.state = running
                debug "there are #{running} #{self.parent} processes for start"
            end

            def <=>(other)
                self.state < 1
            end

            def fix
                require 'etc'
                # ruby is really cool
                uid = 0
                if @params[:user].is_a? Integer
                    uid = @params[:user]
                else
                    uid = Etc.getpwnam(@params[:user]).uid
                end
                Kernel.fork {
                    PProcess.uid = uid
                    PProcess.euid = uid
                    string = @params[:binary] + (@params[:arguments] || "")
                    Puppet::Message.new(
                        :level => :notice,
                        :source => self.parent,
                        :message => "starting"
                    )
                    Kernel.exec(string)
                }
            end
        end
    end
	class Type
		class PProcess < Type
			attr_reader :stat, :path
			@parameters = [:start, :stop, :user, :pattern, :binary, :arguments]
            @name = :process

            @paramdoc[:start] = "How to start the process.  Must be a fully
                qualified path."
            @paramdoc[:stop] = "How to stop the process.  Must be a fully
                qualified path."
            @paramdoc[:user] = "Which user to run the proces as."
            @paramdoc[:pattern] = "The search pattern to use to determine
                whether the process is currently running."
            @paramdoc[:binary] = "The binary to actually execute."
            @paramdoc[:arguments] = "The arguments to pass the binary."

            @doc = "**Disabled.  Use `service` instead.** Manage running
                processes."

			@namevar = :pattern

			Puppet::Relation.new(self, Puppet::Operation::Start, {
				:user => :user,
				:pattern => :pattern,
				:binary => :binary,
				:arguments => :arguments
			})

			Puppet::Relation.new(self, Puppet::Operation::Stop, {
				:user => :user,
				:pattern => :pattern
			})

		end # Puppet.type(:pprocess)
	end # Puppet::Type

end
