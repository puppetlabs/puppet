#!/usr/local/bin/ruby -w

# $Id$

# this is our main way of managing processes right now
#
# a service is distinct from a process in that services
# can only be managed through the interface of an init script
# which is why they have a search path for initscripts and such

module Blink
    class State
        class ServiceRunning < State
            @name = :running

            # this whole thing is annoying
            # i should probably just be using booleans, but for now, i'm not...
            def should=(should)
                case should
                when false,0,"0":
                    should = 0
                when true,1,"1":
                    should = 1
                else
                    Blink.warning "%s: interpreting '%s' as false" %
                        [self.class,should]
                    should = 0
                end
                @should = should
            end

            def retrieve
                self.is = self.running()
                Blink.debug "Running value for '%s' is '%s'" %
                    [self.parent.name,self.is]
            end

            # should i cache this info?
            def running
                begin
                    status = self.parent.initcmd("status")
                    Blink.debug "initcmd status for '%s' is '%s'" %
                        [self.parent.name,status]

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
                        if self.parent.initcmd("start")
                            return :service_started
                        else
                            raise "Failed to start '%s'" % self.parent.name
                        end
                    else
                        Blink.debug "'%s' is already running, yo" % self
                        #Blink.debug "Starting '%s'" % self
                        #unless self.parent.initcmd("start")
                        #    raise "Failed to start %s" % self.name
                        #end
                    end
                elsif status > 0
                    Blink.debug "Stopping '%s'" % self
                    if self.parent.initcmd("stop")
                        return :service_stopped
                    else
                        raise "Failed to stop %s" % self.name
                    end
                else
                    Blink.debug "Not running '%s' and shouldn't be running" % self
                end
            end
        end
    end
	class Type
		class Service < Type
			attr_reader :stat
			@states = [
                Blink::State::ServiceRunning
            ]
			@parameters = [
                :name,
                :pattern
            ]

            @functions = [
                :setpath
            ]

            @name = :service
			@namevar = :name

            @searchpaths = Array.new
            @allowedmethods = [:setpath]

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
                raise "Could not find init script for '%s'" % name
            end

            def Service.setpath(ary)
                # verify each of the paths exists
                #ary.flatten!
                @searchpaths = ary.find_all { |dir|
                    retvalue = false
                    begin
                        retvalue = ::File.stat(dir).directory?
                    rescue => detail
                        Blink.verbose("Directory %s does not exist: %s" % [dir,detail])
                        # just ignore it
                    end
                    # disallow relative paths
                    #if dir !~ /^\//
                    #    retvalue = false
                    #end
                    retvalue
                }
            end

            # it'd be nice if i didn't throw the output away...
            # this command returns true if the exit code is 0, and returns
            # false otherwise
            def initcmd(cmd)
                script = self.initscript

                Blink.debug "Executing '%s %s' as initcmd for '%s'" %
                    [script,cmd,self]

                rvalue = Kernel.system("%s %s" %
                        [script,cmd])

                Blink.debug "'%s' ran with exit status '%s'" %
                    [cmd,rvalue]


                rvalue
            end

            def initscript
                if defined? @initscript
                    return @initscript
                else
                    @initscript = Service.search(self.name)
                end
            end

            def refresh
                self.initcmd("restart")
            end
		end # Blink::Type::Service
	end # Blink::Type
end
