require 'puppet/util/methodhelper'
require 'puppet/module_tool'
require 'puppet/network/format_support'

module Puppet::ModuleTool

  # This class provides a data structure representing a module's metadata.
  # @api private
  class Metadata
    include Puppet::Network::FormatSupport

    attr_reader :module_name

    def initialize
      @data = {
        'name'         => nil,
        'version'      => nil,
        'author'       => 'UNKNOWN',
        'summary'      => 'UNKNOWN',
        'license'      => 'Apache License, Version 2.0',
        'source'       => 'UNKNOWN',
        'dependencies' => []
      }
    end

    # Returns a filesystem-friendly version of this module name.
    def dashed_name
      @data['name'].tr('/', '-') if @data['name']
    end

    # Returns a string that uniquely represents this version of this module.
    def release_name
      return nil unless @data['name'] && @data['version']
      [ dashed_name, @data['version'] ].join('-')
    end

    # Merges the current set of metadata with another metadata hash.  This
    # method also handles the validation of module names and versions, in an
    # effort to be proactive about module publishing constraints.
    def update(data)
      data['author'] ||= @data['author'] unless @data['author'] == 'UNKNOWN'

      if data['name']
        validate_name(data['name'])
        author, name = data['name'].split(/[-\/]/, 2)
        @module_name = name
        data['author'] ||= author
      end

      data['version'] && validate_version(data['version'])
      @data.merge!(data)

      return self
    end

    # Returns a hash of the module's metadata.  Used by Puppet's automated
    # serialization routines.
    #
    # @see Puppet::Network::FormatSupport#to_data_hash
    def to_hash
      @data
    end
    alias :to_data_hash :to_hash

    private

    # Validates that the given module name is both namespaced and well-formed.
    def validate_name(name)
      return if name =~ /\A[a-z0-9]+[-\/][a-z][a-z0-9_]*\Z/i

      namespace, modname = name.split(/[-\/]/, 2)
      modname = :namespace_missing if namespace == ''

      err = case modname
      when nil, '', :namespace_missing
        "the field must be a namespaced module name"
      when /[^a-z0-9_]/i
        "the module name contains non-alphanumeric (or underscore) characters"
      when /^[^a-z]/i
        "the module name must begin with a letter"
      else
        "the namespace contains non-alphanumeric characters"
      end

      raise ArgumentError, "Invalid 'name' field in metadata.json: #{err}"
    end

    # Validates that the version string can be parsed as per SemVer.
    def validate_version(version)
      return if SemVer.valid?(version)

      err = "version string cannot be parsed as a valid Semantic Version"
      raise ArgumentError, "Invalid 'version' field in metadata.json: #{err}"
    end
  end
end
