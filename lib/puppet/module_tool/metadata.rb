require 'puppet/util/methodhelper'
require 'puppet/module_tool'
require 'puppet/network/format_support'
require 'uri'
require 'json'
require 'set'

module Puppet::ModuleTool

  # This class provides a data structure representing a module's metadata.
  # @api private
  class Metadata
    include Puppet::Network::FormatSupport

    attr_accessor :module_name

    DEFAULTS = {
      'name'          => nil,
      'version'       => nil,
      'author'        => nil,
      'summary'       => nil,
      'license'       => 'Apache-2.0',
      'source'        => '',
      'project_page'  => nil,
      'issues_url'    => nil,
      'dependencies'  => Set.new.freeze,
      'data_provider' => nil,
    }

    def initialize
      @data = DEFAULTS.dup
      @data['dependencies'] = @data['dependencies'].dup
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

    alias :name :module_name
    alias :full_module_name :dashed_name

    # Merges the current set of metadata with another metadata hash.  This
    # method also handles the validation of module names and versions, in an
    # effort to be proactive about module publishing constraints.
    def update(data)
      process_name(data) if data['name']
      process_version(data) if data['version']
      process_source(data) if data['source']
      process_data_provider(data) if data['data_provider']
      merge_dependencies(data) if data['dependencies']

      @data.merge!(data)
      return self
    end

    # Validates the name and version_requirement for a dependency, then creates
    # the Dependency and adds it.
    # Returns the Dependency that was added.
    def add_dependency(name, version_requirement=nil, repository=nil)
      validate_name(name)
      validate_version_range(version_requirement) if version_requirement

      if dup = @data['dependencies'].find { |d| d.full_module_name == name && d.version_requirement != version_requirement }
        raise ArgumentError, "Dependency conflict for #{full_module_name}: Dependency #{name} was given conflicting version requirements #{version_requirement} and #{dup.version_requirement}. Verify that there are no duplicates in the metadata.json."
      end

      dep = Dependency.new(name, version_requirement, repository)
      @data['dependencies'].add(dep)

      dep
    end

    # Provides an accessor for the now defunct 'description' property.  This
    # addresses a regression in Puppet 3.6.x where previously valid templates
    # referring to the 'description' property were broken.
    # @deprecated
    def description
      @data['description']
    end

    def dependencies
      @data['dependencies'].to_a
    end

    # Returns a hash of the module's metadata.  Used by Puppet's automated
    # serialization routines.
    #
    # @see Puppet::Network::FormatSupport#to_data_hash
    def to_hash
      @data
    end
    alias :to_data_hash :to_hash

    def to_json
      data = @data.dup.merge('dependencies' => dependencies)

      contents = data.keys.map do |k|
        value = (JSON.pretty_generate(data[k]) rescue data[k].to_json)
        "#{k.to_json}: #{value}"
      end

      "{\n" + contents.join(",\n").gsub(/^/, '  ') + "\n}\n"
    end

    # Expose any metadata keys as callable reader methods.
    def method_missing(name, *args)
      return @data[name.to_s] if @data.key? name.to_s
      super
    end

    private

    # Do basic validation and parsing of the name parameter.
    def process_name(data)
      validate_name(data['name'])
      author, @module_name = data['name'].split(/[-\/]/, 2)

      data['author'] ||= author if @data['author'] == DEFAULTS['author']
    end

    # Do basic validation on the version parameter.
    def process_version(data)
      validate_version(data['version'])
    end

    def process_data_provider(data)
      validate_data_provider(data['data_provider'])
    end

    # Do basic parsing of the source parameter.  If the source is hosted on
    # GitHub, we can predict sensible defaults for both project_page and
    # issues_url.
    def process_source(data)
      if data['source'] =~ %r[://]
        source_uri = URI.parse(data['source'])
      else
        source_uri = URI.parse("http://#{data['source']}")
      end

      if source_uri.host =~ /^(www\.)?github\.com$/
        source_uri.scheme = 'https'
        source_uri.path.sub!(/\.git$/, '')
        data['project_page'] ||= @data['project_page'] || source_uri.to_s
        data['issues_url'] ||= @data['issues_url'] || source_uri.to_s.sub(/\/*$/, '') + '/issues'
      end

    rescue URI::Error
      return
    end

    # Validates and parses the dependencies.
    def merge_dependencies(data)
      data['dependencies'].each do |dep|
        add_dependency(dep['name'], dep['version_requirement'], dep['repository'])
      end

      # Clear dependencies so @data dependencies are not overwritten
      data.delete 'dependencies'
    end

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

    # Validates that the given _value_ is a symbolic name that starts with a letter
    # and then contains only letters, digits, or underscore. Will raise an ArgumentError
    # if that's not the case.
    #
    # @param value [Object] The value to be tested
    def validate_data_provider(value)
      err = nil
      if value.is_a?(String)
        unless value =~ /^[a-zA-Z][a-zA-Z0-9_]*$/
          err = value =~ /^[a-zA-Z]/ ? 'contains non-alphanumeric characters' : 'must begin with a letter'
        end
      else
        err = 'must be a string'
      end
      raise ArgumentError, "field 'data_provider' #{err}" if err
    end

    # Validates that the version range can be parsed by Semantic.
    def validate_version_range(version_range)
      Semantic::VersionRange.parse(version_range)
    rescue ArgumentError => e
      raise ArgumentError, "Invalid 'version_range' field in metadata.json: #{e}"
    end
  end
end
