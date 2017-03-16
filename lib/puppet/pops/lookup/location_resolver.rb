require 'pathname'
require_relative 'interpolation'

module Puppet::Pops
module Lookup
  # Class that keeps track of the original location (as it appears in the declaration, before interpolation),
  # and the fully resolved location, and whether or not the resolved location exists.
  #
  # @api private
  class ResolvedLocation
    attr_reader :original_location, :location

    # @param original_location [String] location as found in declaration. May contain interpolation expressions
    # @param location [Pathname,URI] the expanded location
    # @param exist [Boolean] `true` if the location is assumed to exist
    # @api public
    def initialize(original_location, location, exist)
      @original_location = original_location
      @location = location
      @exist = exist
    end

    # @return [Boolean] `true` if the location is assumed to exist
    # @api public
    def exist?
      @exist
    end

    # @return the resolved location as a string
    def to_s
      @location.to_s
    end
  end

  # Helper methods to resolve interpolated locations
  #
  # @api private
  module LocationResolver
    include Interpolation

    def expand_globs(datadir, declared_globs, lookup_invocation)
      declared_globs.map do |declared_glob|
        glob = datadir + interpolate(declared_glob, lookup_invocation, false)
        Pathname.glob(glob).reject { |path| path.directory? }.map { |path| ResolvedLocation.new(glob.to_s, path, true) }
      end.flatten
    end

    # @param datadir [Pathname] The base when creating absolute paths
    # @param declared_paths [Array<String>] paths as found in declaration. May contain interpolation expressions
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @param is_default_config [Boolean] `true` if this is the default config and non-existent paths should be excluded
    # @param extension [String] Required extension such as '.yaml' or '.json'. Use only if paths without extension can be expected
    # @return [Array<ResolvedLocation>] Array of resolved paths
    def resolve_paths(datadir, declared_paths, lookup_invocation, is_default_config, extension = nil)
      result = []
      declared_paths.each do |declared_path|
        path = interpolate(declared_path, lookup_invocation, false)
        path += extension unless extension.nil? || path.end_with?(extension)
        path = datadir + path
        path_exists = path.exist?
        result << ResolvedLocation.new(declared_path, path, path_exists) unless is_default_config && !path_exists
      end
      result
    end

    # @param declared_uris [Array<String>] paths as found in declaration. May contain interpolation expressions
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @return [Array<ResolvedLocation>] Array of resolved paths
    def expand_uris(declared_uris, lookup_invocation)
      declared_uris.map do |declared_uri|
        uri = URI(interpolate(declared_uri, lookup_invocation, false))
        ResolvedLocation.new(declared_uri, uri, true)
      end
    end

    def expand_mapped_paths(datadir, mapped_path_triplet, lookup_invocation)
      # The scope interpolation method is used directly to avoid unnecessary parsing of the string that otherwise
      # would need to be generated
      mapped_vars = interpolate_method(:scope).call(mapped_path_triplet[0], lookup_invocation, 'mapped_path[0]')

      # No paths here unless the scope lookup returned something
      return EMPTY_ARRAY if mapped_vars.nil? || mapped_vars.empty?

      mapped_vars = [mapped_vars] if mapped_vars.is_a?(String)
      var_key = mapped_path_triplet[1]
      template = mapped_path_triplet[2]
      scope = lookup_invocation.scope
      lookup_invocation.with_local_memory_eluding(var_key) do
        mapped_vars.map do |var|
          # Need to use parent lookup invocation to avoid adding 'var' to the set of variables to track for changes. The
          # variable that 'var' stems from is added above.
          path = scope.with_local_scope(var_key => var) {  datadir + interpolate(template, lookup_invocation, false) }
          ResolvedLocation.new(template, path, path.exist?)
        end
      end
    end
  end
end
end
