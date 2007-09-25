require 'puppet/indirector'
require 'puppet/indirector/indirection'
require 'puppet/util/instance_loader'

# A simple class that can function as the base class for indirected types.
class Puppet::Indirector::Terminus
    require 'puppet/util/docs'
    extend Puppet::Util::Docs

    class << self
        include Puppet::Util::InstanceLoader

        attr_accessor :name, :terminus_type
        attr_reader :abstract_terminus, :indirection

        # Are we an abstract terminus type, rather than an instance with an
        # associated indirection?
        def abstract_terminus?
            abstract_terminus
        end

        # Look up the indirection if we were only provided a name.
        def indirection=(name)
            if name.is_a?(Puppet::Indirector::Indirection)
                @indirection = name
            elsif ind = Puppet::Indirector::Indirection.instance(name)
                @indirection = ind
            else
                raise ArgumentError, "Could not find indirection instance %s for %s" % [name, self.name]
            end
        end

        # Register our subclass with the appropriate indirection.
        # This follows the convention that our terminus is named after the
        # indirection.
        def inherited(subclass)
            longname = subclass.to_s
            if longname =~ /#<Class/
                raise ArgumentError, "Terminus subclasses must have associated constants"
            end
            names = longname.split("::")

            # Convert everything to a lower-case symbol, converting camelcase to underscore word separation.
            name = names.pop.sub(/^[A-Z]/) { |i| i.downcase }.gsub(/[A-Z]/) { |i| "_" + i.downcase }.intern

            subclass.name = name

            # Short-circuit the abstract types, which are those that directly subclass
            # the Terminus class.
            if self == Puppet::Indirector::Terminus
                subclass.mark_as_abstract_terminus
                return
            end

            # Set the terminus type to be the name of the abstract terminus type.
            # Yay, class/instance confusion.
            subclass.terminus_type = self.name

            # This will throw an exception if the indirection instance cannot be found.
            # Do this last, because it also registers the terminus type with the indirection,
            # which needs the above information.
            subclass.indirection = name

            # And add this instance to the instance hash.
            Puppet::Indirector::Terminus.register_terminus_class(subclass)
        end

        # Mark that this instance is abstract.
        def mark_as_abstract_terminus
            @abstract_terminus = true
        end

        def model
            indirection.model
        end

        # Register a class, probably autoloaded.
        def register_terminus_class(klass)
            setup_instance_loading klass.terminus_type
            instance_hash(klass.terminus_type)[klass.name] = klass
        end

        # Return a terminus by name, using the autoloader.
        def terminus_class(type, name)
            setup_instance_loading type
            loaded_instance(type, name)
        end

        private

        def setup_instance_loading(type)
            unless instance_loading?(type)
                instance_load type, "puppet/indirector/%s" % type
            end
        end
    end

    def initialize
        if self.class.abstract_terminus?
            raise Puppet::DevError, "Cannot create instances of abstract terminus types"
        end
    end
    
    def terminus_type
        self.class.terminus_type
    end
    
    def name
        self.class.name
    end
    
    def model
        self.class.model
    end

    def indirection
        self.class.indirection
    end
end
