#!/usr/local/bin/ruby -w

# DISABLED
# I'm only working on services, not processes, right now

module Puppet
    class State
        class ProcessRunning < State
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
                Puppet.debug "there are #{running} #{self.parent} processes for start"
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
                    Process.uid = uid
                    Process.euid = uid
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
		class BProcess < Type
			attr_reader :stat, :path
			@parameters = [:start, :stop, :user, :pattern, :binary, :arguments]
            @name = :process

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

		end # Puppet::Type::BProcess
	end # Puppet::Type

end
