#!/usr/local/bin/ruby -w

# $Id$

# this is our main way of managing processes right now
#
# a service is distinct from a process in that services
# can only be managed through the interface of an init script
# which is why they have a search path for initscripts and such

module Blink
    class Attribute
        class ServiceRunning < Attribute
            @name = :running

            def retrieve
                self.value = self.running()
                Blink.debug "Running value for '%s' is '%s'" %
                    [self.object.name,self.value]
            end

            # should i cache this info?
            def running
                begin
                    status = self.object.initcmd("status")
                    Blink.debug "initcmd status for '%s' is '%s'" %
                        [self.object.name,status]

                    if status # the command succeeded
                        return 1
                    else
                        return 0
                    end
                rescue SystemCallError
                    raise "Could not execute %s" % initscript
                end

            end

            def sync
                if self.running > 0
                    status = 1
                else
                    status = 0
                end
                Blink.debug "'%s' status is '%s' and should be '%s'" %
                    [self,status,should]
                if self.should > 0
                    if status < 1
                        Blink.debug "Starting '%s'" % self
                        unless self.object.initcmd("start")
                            raise "Failed to start %s" % self.name
                        end
                    else
                        Blink.debug "'%s' is already running, yo" % self
                        #Blink.debug "Starting '%s'" % self
                        #unless self.object.initcmd("start")
                        #    raise "Failed to start %s" % self.name
                        #end
                    end
                elsif status > 0
                    Blink.debug "Stopping '%s'" % self
                    unless self.object.initcmd("stop")
                        raise "Failed to stop %s" % self.name
                    end
                else
                    Blink.debug "Not running '%s' and shouldn't be running" % self
                end
            end
        end
    end
	class Objects
		class Service < Objects
			attr_reader :stat
			@params = [
                Blink::Attribute::ServiceRunning,
                :name,
                :pattern
            ]

            @name = :service
			@namevar = :name

            @searchpaths = Array.new

            def Service.addpath(path)
                unless @searchpaths.include?(path)
                    # XXX should we check to see if the path exists?
                    @searchpaths.push(path)
                end
            end

            def Service.search(name)
                @searchpaths.each { |path|
                    # must specify that we want the top-level File, not Blink::...::File
                    fqname = ::File.join(path,name)
                    begin
                        stat = ::File.stat(fqname)
                    rescue
                        # should probably rescue specific errors...
                        Blink.debug("Could not find %s in %s" % [name,path])
                        next
                    end

                    # if we've gotten this far, we found a valid script
                    return fqname
                }
            end

            # it'd be nice if i didn't throw the output away...
            # this command returns true if the exit code is 0, and returns
            # false otherwise
            def initcmd(cmd)
                script = self.initscript

                #Blink.debug "Executing '%s %s' as initcmd for '%s'" %
                #    [script,cmd,self]

                rvalue = Kernel.system("%s %s" %
                        [script,cmd])

                #Blink.debug "'%s' ran with exit status '%s'" %
                #    [cmd,rvalue]


                rvalue
            end

            def initscript
                if defined? @initscript
                    return @initscript
                else
                    @initscript = Service.search(self.name)
                end
            end
		end # Blink::Objects::BProcess
	end # Blink::Objects
end
