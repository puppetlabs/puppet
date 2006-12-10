require 'puppet'
require 'puppet/util/classgen'

# Methods dealing with Type management.  This module gets included into the
# Puppet::Type class, it's just split out here for clarity.
module Puppet::MetaType
module Manager
    include Puppet::Util::ClassGen

    # remove all type instances; this is mostly only useful for testing
    def allclear
        Puppet::Event::Subscription.clear
        @types.each { |name, type|
            type.clear
        }
    end

    # iterate across all of the subclasses of Type
    def eachtype
        @types.each do |name, type|
            # Only consider types that have names
            #if ! type.parameters.empty? or ! type.validstates.empty?
                yield type 
            #end
        end
    end

    # Load all types.  Only currently used for documentation.
    def loadall
        typeloader.loadall
    end

    # Do an on-demand plugin load
    def loadplugin(name)
        paths = Puppet[:pluginpath].split(":")
        unless paths.include?(Puppet[:plugindest])
            Puppet.notice "Adding plugin destination %s to plugin search path" %
                Puppet[:plugindest]
            Puppet[:pluginpath] += ":" + Puppet[:plugindest]
        end
        paths.each do |dir|
            file = ::File.join(dir, name.to_s + ".rb")
            if FileTest.exists?(file)
                begin
                    load file
                    Puppet.info "loaded %s" % file
                    return true
                rescue LoadError => detail
                    Puppet.info "Could not load plugin %s: %s" %
                        [file, detail]
                    return false
                end
            end
        end
    end

    # Define a new type.
    def newtype(name, parent = nil, &block)
        # First make sure we don't have a method sitting around
        name = symbolize(name)
        newmethod = "new#{name.to_s}"

        # Used for method manipulation.
        selfobj = metaclass()

        @types ||= {}

        if @types.include?(name)
            if self.respond_to?(newmethod)
                # Remove the old newmethod
                selfobj.send(:remove_method,newmethod)
            end
        end

        # Then create the class.
        klass = genclass(name,
            :parent => (parent || Puppet::Type),
            :overwrite => true,
            :hash => @types,
            &block
        )

        # Now define a "new<type>" method for convenience.
        if self.respond_to? newmethod
            # Refuse to overwrite existing methods like 'newparam' or 'newtype'.
            Puppet.warning "'new#{name.to_s}' method already exists; skipping"
        else
            selfobj.send(:define_method, newmethod) do |*args|
                klass.create(*args)
            end
        end

        # If they've got all the necessary methods defined and they haven't
        # already added the state, then do so now.
        if klass.ensurable? and ! klass.validstate?(:ensure)
            klass.ensurable
        end

        # Now set up autoload any providers that might exist for this type.
        klass.providerloader = Puppet::Autoload.new(klass,
            "puppet/provider/#{klass.name.to_s}"
        )

        # We have to load everything so that we can figure out the default type.
        klass.providerloader.loadall()

        klass
    end
    
    # Remove an existing defined type.  Largely used for testing.
    def rmtype(name)
        # Then create the class.
        klass = rmclass(name,
            :hash => @types
        )
        
        if respond_to?("new" + name.to_s)
            metaclass.send(:remove_method, "new" + name.to_s)
        end
    end

    # Return a Type instance by name.
    def type(name)
        @types ||= {}

        name = symbolize(name)

        if t = @types[name]
            return t
        else
            if typeloader.load(name)
                unless @types.include? name
                    Puppet.warning "Loaded puppet/type/#{name} but no class was created"
                end
            else
                # If we can't load it from there, try loading it as a plugin.
                loadplugin(name)
            end

            return @types[name]
        end
    end

    # Create a loader for Puppet types.
    def typeloader
        unless defined? @typeloader
            @typeloader = Puppet::Autoload.new(self,
                "puppet/type", :wrap => false
            )
        end

        @typeloader
    end
end
end

# $Id$
