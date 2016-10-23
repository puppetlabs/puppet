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
  end

  # Helper methods to resolve interpolated locations
  #
  # @api private
  module LocationResolver
    include Interpolation

    def expand_globs(datadir, declared_globs, lookup_invocation)
      declared_globs.map do |declared_glob|
        glob = interpolate(declared_glob, lookup_invocation, false)
        Pathname.glob(datadir, glob).reject { |path| path.directory? }.map { |path| ResolvedLocation.new(glob, path, true) }
      end.flatten
    end

    # @param datadir [Pathname] The base when creating absolute paths
    # @param declared_paths [Array<String>] paths as found in declaration. May contain interpolation expressions
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @param extension [String] Required extension such as '.yaml' or '.json'. Use only if paths without extension can be expected
    # @return [Array<ResolvedLocation>] Array of resolved paths
    def resolve_paths(datadir, declared_paths, lookup_invocation, extension = nil)
      declared_paths.map do |declared_path|
        path = interpolate(declared_path, lookup_invocation, false)
        path += extension unless extension.nil? || path.end_with?(extension)
        path = datadir + path
        ResolvedLocation.new(declared_path, path, path.exist?)
      end
    end

    # @param declared_uris [Array<String>] paths as found in declaration. May contain interpolation expressions
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @return [Array<ResolvedLocation>] Array of resolved paths
    def resolve_uris(declared_uris, lookup_invocation)
      declared_uris.map do |declared_uri|
        uri = URI(interpolate(declared_uri, lookup_invocation, false))
        ResolvedLocation.new(declared_uri, uri, true)
      end
    end
  end
end
end
