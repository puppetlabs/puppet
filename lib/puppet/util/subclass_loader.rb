# A module for loading subclasses into an array and retrieving
# them by name.  Also sets up a method for each class so
# that you can just do Klass.subclass, rather than Klass.subclass(:subclass).
#
# This module is currently used by network handlers and clients.
module Puppet::Util::SubclassLoader
    attr_accessor :loader, :classloader

    # Iterate over each of the subclasses.
    def each
        @subclasses ||= []
        @subclasses.each { |c| yield c }
    end

    # The hook method that sets up subclass loading.  We need the name
    # of the method to create and the path in which to look for them.
    def handle_subclasses(name, path)
        unless self.is_a?(Class)
            raise ArgumentError, "Must be a class to use SubclassLoader"
        end
        @subclasses = []
        @loader = Puppet::Util::Autoload.new(self,
            path, :wrap => false
        )

        @subclassname = name

        @classloader = self

        # Now create a method for retrieving these subclasses by name.  Note
        # that we're defining a class method here, not an instance.
        meta_def(name) do |subname|
            subname = subname.to_s.downcase

            unless c = @subclasses.find { |c| c.name.to_s.downcase == subname }
                loader.load(subname)
                c = @subclasses.find { |c| c.name.to_s.downcase == subname }

                # Now make the method that returns this subclass.  This way we
                # normally avoid the method_missing method.
                if c and ! respond_to?(subname)
                    define_method(subname) { c }
                end
            end
            return c
        end
    end

    # Add a new class to our list.  Note that this has to handle subclasses of
    # subclasses, thus the reason we're keeping track of the @@classloader.
    def inherited(sub)
        @subclasses ||= []
        sub.classloader = self.classloader
        if self.classloader == self
            @subclasses << sub
        else
            @classloader.inherited(sub)
        end
    end

    # See if we can load a class.
    def method_missing(method, *args)
        unless self == self.classloader
            super
        end
        return nil unless defined? @subclassname
        if c = self.send(@subclassname, method)
            return c
        else
            return nil
        end
    end

    # Retrieve or calculate a name.
    def name(dummy_argument=:work_arround_for_ruby_GC_bug)
        unless defined? @name
            @name = self.to_s.sub(/.+::/, '').intern
        end

        return @name
    end

    # Provide a list of all subclasses.
    def subclasses
        @loader.loadall
        @subclasses.collect { |klass| klass.name }
    end
end

