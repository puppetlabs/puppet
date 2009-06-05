require 'puppet'
require 'puppet/util/classgen'

# Methods dealing with Type management.  This module gets included into the
# Puppet::Type class, it's just split out here for clarity.
module Puppet::MetaType
module Manager
    include Puppet::Util::ClassGen

    # remove all type instances; this is mostly only useful for testing
    def allclear
        @types.each { |name, type|
            type.clear
        }
    end

    # iterate across all of the subclasses of Type
    def eachtype
        @types.each do |name, type|
            # Only consider types that have names
            #if ! type.parameters.empty? or ! type.validproperties.empty?
                yield type
            #end
        end
    end

    # Load all types.  Only currently used for documentation.
    def loadall
        typeloader.loadall
    end

    # Define a new type.
    def newtype(name, options = {}, &block)
        # Handle backward compatibility
        unless options.is_a?(Hash)
            Puppet.warning "Puppet::Type.newtype(%s) now expects a hash as the second argument, not %s" % [name, options.inspect]
            options = {:parent => options}
        end

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

        options = symbolize_options(options)

        if parent = options[:parent]
            options.delete(:parent)
        end

        # Then create the class.
        klass = genclass(name,
            :parent => (parent || Puppet::Type),
            :overwrite => true,
            :hash => @types,
            :attributes => options,
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
        # already added the property, then do so now.
        if klass.ensurable? and ! klass.validproperty?(:ensure)
            klass.ensurable
        end

        # Now set up autoload any providers that might exist for this type.
        klass.providerloader = Puppet::Util::Autoload.new(klass,
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

        name = name.to_s.downcase.to_sym

        if t = @types[name]
            return t
        else
            if typeloader.load(name)
                unless @types.include? name
                    Puppet.warning "Loaded puppet/type/#{name} but no class was created"
                end
            end

            return @types[name]
        end
    end

    # Create a loader for Puppet types.
    def typeloader
        unless defined? @typeloader
            @typeloader = Puppet::Util::Autoload.new(self,
                "puppet/type", :wrap => false
            )
        end

        @typeloader
    end
end
end

