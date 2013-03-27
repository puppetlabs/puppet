require 'puppet/pops/api'

module Puppet; module Pops; module Impl; end; end; end;

module Puppet::Pops::Imple::Loader
  # Abstract loader implementation
  # A derived class should implement #find(name, executor), and possible handle "miss caching". This
  # abstract implementation handles caching of found items.
  #
  class BaseLoader < Puppet::Pops::Impl::Loader::Loader
    include Puppet::Pops::API::Utils
    Utils = Puppet::Pops::API::Utils

    attr_reader :parent
    def initialize parent_loader
      @parent = parent_loader # the higher priority loader to consult
      @named_values = {}  # hash name => NamedEntry
      @last_name = nil    # the last name asked for (optimization)
      @last_result = nil  # the value of the last name (optimization)
    end

    # API
    def load(name, executor)
      # The check for "last queried name" is an optimization when a module searches. First it checks up its parent
      # chain, then itself, and then delegates to modules it depends on.
      # These modules are typically parented by the same
      # loader as the one initiating the search. It is inefficient to again try to search the same loader for
      # the same name.
      if name == @last_name
        @last_result
      else
        @last_result = internal_load(name, executor)
        @last_name = name
        @last_result
      end
    end

    # API
    def [] name
      if found = get_entry(name)
        found.value
      else
        nil
      end
    end

    # API
    def get_entry(name)
      name = Utils.relativize_name(name)
      @named_values[name]
    end

    # API
    def set_entry(name, value, origin = nil)
      name = Utils.relativize_name(name)
      # Not allowed to assign to $0, $010, $0x10, $1.2 etc
      if Utils.is_numeric?(name)
        raise Puppet::Pops::ImmutableError.new("Illegal attempt to assign a numeric name '#{name}' at #{origin_label(origin)}.")
      end
      if entry = @named_values[name]
        origin_info = entry.origin ? " Originally set at #{origin_label(entry.origin)}." : ""
        raise Puppet::Pops::ImmutableError.new("Attempt to redefine item named '#{name}' at #{origin_label(origin)}.#{origin_info}")
      end
      # TODO: the classification of NamedEntry type is smelly, the :loaded is not used
      @named_values[name] = Puppet::Pops::NamedEntry.new(:loaded, name, value, origin).freeze
    end

    private

    # Should not really be here - TODO: Label provider
    def origin_label origin
      if origin && origin.is_a?(URI)
        origin.to_s
      elsif origin.respond_to?(:uri)
        origin.uri.to_s
      else
        nil
      end
    end

    def internal_load(name, executor)
      rname = Utils.relativize_name(name)
      if loaded = self[rname]
        loaded
      elsif loaded = parent.load(name, executor)
        loaded
      elsif loaded = find(name, executor)
        set_entry(name, loaded, nil) # TODO: origin of loaded
        loaded
      end
    end

  end
end