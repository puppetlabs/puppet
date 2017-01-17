# this file contains a couple of utility functions that didn't fit anywhere else, and seem reasonably benign.

module Puppet
  class Type
    include Enumerable

    # Returns a string representation of the resource's containment path in
    # the catalog.
    # @return [String]
    def path
      @path ||= '/' + pathbuilder.join('/')
    end

    # Returns an array of strings representing the containment hierarchy
    # (types/classes) that make up the path to the resource from the root
    # of the catalog.  This is mostly used for logging purposes.
    #
    # @api private
    def pathbuilder
      if p = parent
        [p.pathbuilder, self.ref].flatten
      else
        [self.ref]
      end
    end

    # Creates a log entry with the given message at the log level specified by the parameter `loglevel`
    # @return [void]
    # @todo (DS) only usage I've found was in the Component resource type
    def log(msg)

      Puppet::Util::Log.create(

          :level => @parameters[:loglevel].value,
          :message => msg,

          :source => self
      )
    end

    # Creates a transaction event.
    # Called by Transaction or by a property.
    # Merges the given options with the options `:resource`, `:file`, `:line`, and `:tags`, initialized from
    # values in this object. For possible options to pass (if any ????) see {Puppet::Transaction::Event}.
    # @todo Needs a better explanation "Why should I care who is calling this method?", What do I need to know
    #   about events and how they work? Where can I read about them?
    # @param options [Hash] options merged with a fixed set of options defined by this method, passed on to {Puppet::Transaction::Event}.
    # @return [Puppet::Transaction::Event] the created event
    def event(options = {})
      Puppet::Transaction::Event.new({:resource => self, :file => file, :line => line, :tags => tags}.merge(options))
    end

    # @todo What is this used for? Needs a better explanation.
    # @return [???] the version of the catalog or 0 if there is no catalog.
    def version
      return 0 unless catalog
      catalog.version
    end

    # Returns true if the type's notion of name is the identity of a resource.
    # See the overview of this class for a longer explanation of the concept _isomorphism_.
    # Defaults to true.
    #
    # @return [Boolean] true, if this type's name is isomorphic with the object
    def self.isomorphic?
      if defined?(@isomorphic)
        return @isomorphic
      else
        return true
      end
    end

    # @todo check that this gets documentation (it is at the class level as well as instance).
    # (see isomorphic?)
    def isomorphic?
      self.class.isomorphic?
    end

    # Returns true if the instance is a managed instance.
    # A 'yes' here means that the instance was created from the language, vs. being created
    # in order resolve other questions, such as finding a package in a list.
    # @note An object that is managed always stays managed, but an object that is not managed
    #   may become managed later in its lifecycle.
    # @return [Boolean] true if the object is managed
    def managed?
      # Once an object is managed, it always stays managed; but an object
      # that is listed as unmanaged might become managed later in the process,
      # so we have to check that every time
      if @managed
        return @managed
      else
        @managed = false
        properties.each { |property|
          s = property.should
          if s and ! property.class.unmanaged
            @managed = true
            break
          end
        }
        return @managed
      end
    end

    ###############################
    # Code related to the container behaviour.

    # Returns true if the search should be done in depth-first order.
    # This implementation always returns false.
    # @todo What is this used for?
    #
    # @return [Boolean] true if the search should be done in depth first order.
    #
    def depthfirst?
      false
    end

    ###############################
    # Code related to evaluating the resources.

    # Returns the ancestors - WHAT?
    # This implementation always returns an empty list.
    # @todo WHAT IS THIS ?
    # @return [Array<???>] returns a list of ancestors.
    def ancestors
      []
    end

    # @return [String] the name of this object's class
    # @todo Would that be "file" for the "File" resource type? of "File" or something else?
    #
    def type
      self.class.name
    end

    # Returns the `noop` run mode status of this.
    # @return [Boolean] true if running in noop mode.
    def noop?
      # If we're not a host_config, we're almost certainly part of
      # Settings, and we want to ignore 'noop'
      return false if catalog and ! catalog.host_config?

      if defined?(@noop)
        @noop
      else
        Puppet[:noop]
      end
    end

    # (see #noop?)
    def noop
      noop?
    end

    # Returns the name of this type (if specified) or the parent type #to_s.
    # The returned name is on the form "Puppet::Type::<name>", where the first letter of name is
    # capitalized.
    # @return [String] the fully qualified name Puppet::Type::<name> where the first letter of name is capitalized
    #
    def self.to_s
      if defined?(@name)
        "Puppet::Type::#{@name.to_s.capitalize}"
      else
        super
      end
    end

    # Returns a reference to this as a string in "Type[name]" format.
    # @return [String] a reference to this object on the form 'Type[name]'
    #
    def ref
      # memoizing this is worthwhile ~ 3 percent of calls are the "first time
      # around" in an average run of Puppet. --daniel 2012-07-17
      @ref ||= "#{self.class.name.to_s.capitalize}[#{self.title}]"
    end

    # Produces a reference to this in reference format.
    # @see #ref
    #
    def to_s
      self.ref
    end

  end
end
