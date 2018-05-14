require 'puppet/module_tool'
require 'puppet/network/format_support'

module Puppet::ModuleTool

  class Dependency
    include Puppet::Network::FormatSupport

    attr_reader :full_module_name, :username, :name, :version_requirement, :repository

    # Instantiates a new module dependency with a +full_module_name+ (e.g.
    # "myuser-mymodule"), and optional +version_requirement+ (e.g. "0.0.1") and
    # optional repository (a URL string).
    def initialize(full_module_name, version_requirement = nil, repository = nil)
      @full_module_name = full_module_name
      # TODO: add error checking, the next line raises ArgumentError when +full_module_name+ is invalid
      @username, @name = Puppet::ModuleTool.username_and_modname_from(full_module_name)
      @version_requirement = version_requirement
      @repository = repository ? Puppet::Forge::Repository.new(repository, nil) : nil
    end

    # We override Object's ==, eql, and hash so we can more easily find identical
    # dependencies.
    def ==(o)
      self.hash == o.hash
    end

    alias :eql? :==

    def hash
      [@full_module_name, @version_requirement, @repository].hash
    end

    def to_data_hash
      result = { :name => @full_module_name }
      result[:version_requirement] = @version_requirement if @version_requirement && ! @version_requirement.nil?
      result[:repository] = @repository.to_s if @repository && ! @repository.nil?
      result
    end
  end
end
