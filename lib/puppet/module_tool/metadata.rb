require 'puppet/util/methodhelper'
require 'puppet/module_tool'
require 'puppet/network/format_support'
require 'uri'
require 'json'

module Puppet::ModuleTool

  # This class provides a data structure representing a module's metadata.
  # @api private
  class Metadata
    include Puppet::Network::FormatSupport

    attr_accessor :module_name

    DEFAULTS = {
      'name'         => nil,
      'version'      => nil,
      'author'       => nil,
      'summary'      => nil,
      'license'      => 'Apache 2.0',
      'source'       => '',
      'project_page' => nil,
      'issues_url'   => nil,
      'dependencies' => [].freeze,
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

    def to_json
      # This is used to simulate an ordered hash.  In particular, some keys
      # are promoted to the top of the serialized hash (while others are
      # demoted) for human-friendliness.
      #
      # This particularly works around the lack of ordered hashes in 1.8.7.
      promoted_keys = %w[ name version author summary license source ]
      demoted_keys = %w[ dependencies ]
      keys = @data.keys
      keys -= promoted_keys
      keys -= demoted_keys

      contents = (promoted_keys + keys + demoted_keys).map do |k|
        value = (JSON.pretty_generate(@data[k]) rescue @data[k].to_json)
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
