require 'puppet/pops/api'
require 'puppet/pops/impl'
require 'puppet/pops/impl/match_scope'

require 'uri'

module Puppet::Pops::Impl
  class BaseScope < Puppet::Pops::Scope
    include Puppet::Pops::API::Utils
    Utils = Puppet::Pops::API::Utils

    def initialize
      super
      @data         = Hash.new
      @variables    = Hash.new
      @match_scope  = MatchScope.new
      @parent_scope = nil
    end

    # API IMPL
    def set_match_data(match_data=nil, origin = nil)
      # TODO: Why doesn't match_scope = ... work? it has a private accessor for :match_scope
      @match_scope = Puppet::Pops::Impl::MatchScope.new(match_data, origin)
    end

    # API IMPL
    def get_variable(name, missing_value = nil)
      if entry = get_variable_entry(name)
        entry.value
      else
        missing_value || (raise Puppet::Pops::NoValueError.new("No variable named '#{name}' was found"))
      end
    end

    # API IMPL
    def get_data(type, name, missing_value = nil)
      if entry = get_data_entry(type, name)
        entry.value
      else
        missing_value || (raise Puppet::Pops::NoValueError.new("No #{type} named '#{name}' was found"))
      end
    end

    # API IMPL
    def set_variable(name, value, origin = nil)
      name = Utils.relativize_name(name)
      # Not allowed to assign to $0, $010, $0x10, $1.2 etc
      if Utils.is_numeric?(name)
        raise Puppet::Pops::ImmutableError.new("Illegal attempt to assign a numeric variable name '#{name}' at #{origin_label(origin)}.")
      end
      if entry = variables[name]
        origin_info = entry.origin ? " Originally set at #{origin_label(entry.origin)}." : ""
        raise Puppet::Pops::ImmutableError.new("Assigning to already assigned variable named '#{name}' at #{origin_label(origin)}.#{origin_info}")
      end
      variables[name] = Puppet::Pops::NamedEntry.new(:variable, name, value, origin).freeze
    end

    # API IMPL
    def set_data(type, name, value, origin = nil)
      type = type.to_s.downcase.to_sym unless type.is_a?(Symbol)
      data[type] = Hash.new unless data.has_key? type
      t = data[type]
      if entry = t[name]
        origin_info = entry.origin ? " Originally set at #{origin_label(entry.origin)}." : ""
        raise Puppet::Pops::ImmutableError.new("Assigning to already assigned #{type} named '#{name}' at #{origin_label(origin)}.#{origin_info}")
      end
      t[name] = Puppet::Pops::NamedEntry.new(type, name, value, origin).freeze
    end

    # API IMPL
    def get_variable_entry(name)
      number = Utils.to_n(name)
      if number
        get_match_scope_entry(number)
      else    
        name = Utils.relativize_name(name)
        variables[name]
      end
    end

    # API IMPL
    def get_data_entry(type, name)
      type = type.to_s.downcase.to_sym unless type.is_a?(Symbol)
      begin
         data[type][name]
      rescue NameError => e
        nil 
      end 
    end

    # API IMPL
    def [] (*args)
      case args.length
      when 1 then get_variable_entry(*args)
      when 2 then get_data_entry(*args)
      else
        raise ArgumentError.new("Scope#[]() accepts (variable_name), or (type, name) as arguments. Got #{args}.")
      end
    end


    # NOT API
    def local_scope()
      scope = LocalScope.new
      scope.parent_scope = self
      scope
    end
    
    # NOT API 
    def named_scope(name)
      scope = NamedScope.new(name)
      # Note that names scopes are always parented by the top scope
      scope.parent_scope = top_scope
      scope
    end
    
    # NOT API
    def object_scope(o, extra_var_hash = {})
      scope = ObjectScope.new(o, extra_var_hash)
      scope.parent_scope = top_scope
      scope
    end

    # NOT API
    def top_scope
      return self if self.is_top_scope?
      raise "Internal Error: there is no top scope!" unless parent_scope
      parent_scope.top_scope
    end
    
    protected

    # NOT API
    attr_accessor :data, :variables, :match_scope, :parent_scope

    # NOT API
    def get_match_scope_entry(name) 
      if match_scope 
        match_scope.get_entry(Utils.to_n(name))
      else
        nil
      end
    end

    # NOT API
    def origin_label origin
      if origin && origin.is_a?(URI)
        origin.to_s
      elsif origin.respond_to?(:uri)
        origin.uri.to_s
      else
        nil
      end
    end

  end  
end
require 'puppet/pops/impl/local_scope'
require 'puppet/pops/impl/named_scope'

