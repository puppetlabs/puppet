require 'puppet/node/facts'
require 'puppet/indirector/code'

class Puppet::Node::Facts::Facter < Puppet::Indirector::Code
    desc "Retrieve facts from Facter.  This provides a somewhat abstract interface
        between Puppet and Facter.  It's only `somewhat` abstract because it always
        returns the local host's facts, regardless of what you attempt to find."

    def self.loaddir(dir, type)
        return unless FileTest.directory?(dir)

        Dir.entries(dir).find_all { |e| e =~ /\.rb$/ }.each do |file|
            fqfile = ::File.join(dir, file)
            begin
                Puppet.info "Loading %s %s" % 
                    [type, ::File.basename(file.sub(".rb",''))]
                Timeout::timeout(self.timeout) do
                    load fqfile
                end
            rescue => detail
                Puppet.warning "Could not load %s %s: %s" % [type, fqfile, detail]
            end
        end
    end

    def self.loadfacts
        # Add any per-module fact directories to the factpath
        module_fact_dirs = Puppet[:modulepath].split(":").collect do |d|
            Dir.glob("%s/*/plugins/facter" % d)
        end.flatten
        dirs = module_fact_dirs + Puppet[:factpath].split(":")
        x = dirs.each do |dir|
            loaddir(dir, "fact")
        end
    end

    def self.timeout
        timeout = Puppet[:configtimeout]
        case timeout
        when String:
            if timeout =~ /^\d+$/
                timeout = Integer(timeout)
            else
                raise ArgumentError, "Configuration timeout must be an integer"
            end
        when Integer: # nothing
        else
            raise ArgumentError, "Configuration timeout must be an integer"
        end

        return timeout
    end

    def initialize(*args)
        super
        self.class.loadfacts
    end

    def destroy(facts)
        raise Puppet::DevError, "You cannot destroy facts in the code store; it is only used for getting facts from Facter"
    end

    # Look a host's facts up in Facter.
    def find(request)
        Puppet::Node::Facts.new(request.key, Facter.to_hash)
    end

    def save(facts)
        raise Puppet::DevError, "You cannot save facts to the code store; it is only used for getting facts from Facter"
    end
end
