require 'puppet/util/loadedfile'
require 'puppet/network/rights'

module Puppet
    class ConfigurationError < Puppet::Error; end
    class Network::AuthConfig < Puppet::Util::LoadedFile
        Puppet.config.setdefaults(:puppet,
            :authconfig => [ "$confdir/namespaceauth.conf",
                "The configuration file that defines the rights to the different
                namespaces and methods.  This can be used as a coarse-grained
                authorization system for both ``puppetd`` and ``puppetmasterd``."
            ]
        )

        def self.main
            unless defined? @main
                @main = self.new()
            end
            @main
        end

        # Just proxy the setting methods to our rights stuff
        [:allow, :deny].each do |method|
            define_method(method) do |*args|
                @rights.send(method, *args)
            end         
        end

        # Here we add a little bit of semantics.  They can set auth on a whole
        # namespace or on just a single method in the namespace.
        def allowed?(request)
            name        = request.call.intern
            namespace   = request.handler.intern
            method      = request.method.intern

            read()

            if @rights.include?(name)
                return @rights[name].allowed?(request.name, request.ip)
            elsif @rights.include?(namespace)
                return @rights[namespace].allowed?(request.name, request.ip)
            else
                return false
            end
        end

        # Does the file exist?  Puppetmasterd does not require it, but
        # puppetd does.
        def exists?
            FileTest.exists?(@file)
        end

        def initialize(file = nil, parsenow = true)
            @file ||= Puppet[:authconfig]

            unless @file
                raise Puppet::DevError, "No authconfig file defined"
            end
            return unless self.exists?
            super(@file)
            @rights = Puppet::Network::Rights.new
            @configstamp = @configstatted = nil
            @configtimeout = 60

            if parsenow
                read()
            end
        end

        # Read the configuration file.
        def read
            return unless FileTest.exists?(@file)

            if @configstamp
                if @configtimeout and @configstatted
                    if Time.now - @configstatted > @configtimeout
                        @configstatted = Time.now
                        tmp = File.stat(@file).ctime

                        if tmp == @configstamp
                            return
                        else
                            Puppet.notice "%s vs %s" % [tmp, @configstamp]
                        end
                    else
                        return
                    end
                else    
                    Puppet.notice "%s and %s" % [@configtimeout, @configstatted]
                end
            end

            parse()

            @configstamp = File.stat(@file).ctime
            @configstatted = Time.now
        end

        private

        def parse
            newrights = Puppet::Network::Rights.new
            begin
                File.open(@file) { |f|
                    right = nil
                    count = 1
                    f.each { |line|
                        case line
                        when /^\s*#/: next # skip comments
                        when /^\s*$/: next # skip blank lines
                        when /\[([\w.]+)\]/: # "namespace" or "namespace.method"
                            name = $1
                            if newrights.include?(name)
                                raise FileServerError, "%s is already set at %s" %
                                    [newrights[name], name]
                            end
                            newrights.newright(name)
                            right = newrights[name]
                        when /^\s*(\w+)\s+(.+)$/:
                            var = $1
                            value = $2
                            case var
                            when "allow":
                                value.split(/\s*,\s*/).each { |val|
                                    begin
                                        right.info "allowing %s access" % val
                                        right.allow(val)
                                    rescue AuthStoreError => detail
                                        raise ConfigurationError, "%s at line %s of %s" %
                                            [detail.to_s, count, @config]
                                    end
                                }
                            when "deny":
                                value.split(/\s*,\s*/).each { |val|
                                    begin
                                        right.info "denying %s access" % val
                                        right.deny(val)
                                    rescue AuthStoreError => detail
                                        raise ConfigurationError, "%s at line %s of %s" %
                                            [detail.to_s, count, @config]
                                    end
                                }
                            else
                                raise ConfigurationError,
                                    "Invalid argument '%s' at line %s" % [var, count]
                            end
                        else
                            raise ConfigurationError, "Invalid line %s: %s" % [count, line]
                        end
                        count += 1
                    }
                }
            rescue Errno::EACCES => detail
                Puppet.err "Configuration error: Cannot read %s; cannot serve" % @file
                #raise Puppet::Error, "Cannot read %s" % @config
            rescue Errno::ENOENT => detail
                Puppet.err "Configuration error: '%s' does not exit; cannot serve" %
                    @file
                #raise Puppet::Error, "%s does not exit" % @config
            #rescue FileServerError => detail
            #    Puppet.err "FileServer error: %s" % detail
            end

            # Verify each of the rights are valid.
            # We let the check raise an error, so that it can raise an error
            # pointing to the specific problem.
            newrights.each { |name, right|
                right.valid?
            }
            @rights = newrights
        end
    end
end

# $Id$
