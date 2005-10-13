module Puppet
    module ServiceTypes
        module InitSvc
            # Make sure we've got a search path set up.  If they don't
            # specify one, try to determine one.
            def configchk
                unless defined? @searchpaths
                    @searchpaths = []
                end
                unless @searchpaths.length > 0
                    if init = self.defaultinit
                        Puppet.notice "Adding default init"
                        @searchpaths << init
                    else
                        Puppet.notice "No default init for %s" %
                            Facter["operatingsystem"].value

                        raise Puppet::Error.new(
                            "You must specify a valid search path for service %s" %
                            self.name
                        )
                    end
                end
            end

            # Get the default init path.
            def defaultinit
                unless defined? @defaultinit
                    case Facter["operatingsystem"].value
                    when "FreeBSD":
                        @defaultinit = "/etc/rc.d"
                    else
                        @defaultinit = "/etc/init.d"
                        @defaultrc = "/etc/rc%s.d"
                    end
                end

                return @defaultinit
            end

            # Mark that our init script supports 'status' commands.
            def hasstatus=(value)
                case value
                when true, "true": @parameters[:hasstatus] = true
                when false, "false": @parameters[:hasstatus] = false
                else
                    raise Puppet::Error, "Invalid 'hasstatus' value %s" %
                        value.inspect
                end
            end

            # it'd be nice if i didn't throw the output away...
            # this command returns true if the exit code is 0, and returns
            # false otherwise
            def initcmd(cmd)
                script = self.initscript

                Puppet.debug "Executing '%s %s' as initcmd for '%s'" %
                    [script,cmd,self]

                rvalue = Kernel.system("%s %s" %
                        [script,cmd])

                Puppet.debug "'%s' ran with exit status '%s'" %
                    [cmd,rvalue]


                rvalue
            end

            # Where is our init script?
            def initscript
                if defined? @initscript
                    return @initscript
                else
                    @initscript = self.search(self.name)
                end
            end

            # Store the search path for init scripts.  This will generally not
            # be called.
            def parampath=(ary)
                unless ary.is_a?(Array)
                    ary = [ary]
                end
                @parameters[:path] = ary
                @searchpaths = ary.find_all { |dir|
                    File.directory?(dir)
                }
            end

            # Enable a service, so it's started at boot time.  This basically
            # just creates links in the RC directories, which means that, well,
            # we need to know where the rc directories are.
            # FIXME This should probably be a state or something, and
            # it should actually create use Symlink objects...
            # At this point, people should just link objects for enabling,
            # if they're running on a system that doesn't have a tool to
            # manage init script links.
            #def enable
            #end

            #def disable
            #end

            def search(name)
                @searchpaths.each { |path|
                    fqname = File.join(path,name)
                    begin
                        stat = File.stat(fqname)
                    rescue
                        # should probably rescue specific errors...
                        Puppet.debug("Could not find %s in %s" % [name,path])
                        next
                    end

                    # if we've gotten this far, we found a valid script
                    return fqname
                }
                raise Puppet::Error, "Could not find init script for '%s'" % name
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
    end
end
