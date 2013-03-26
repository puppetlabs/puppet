require 'puppet/pops/api'
require 'puppet/pops/impl/loader/uri_helper'
require 'rubygems'
require 'set'
require 'file'


module Puppet; module Pops; module Impl; module Loader

# A System loader loads "evaluateable" files found relative to a set of given roots. The path relative to
# the root consists of the name segments in the given name.
# A System loader can scan one or multiple roots. Root pats are given as file system paths, or as
# URIs. The URI may have no scheme (interpreted as a file), file: scheme, or gem:. The gem: scheme allows
# a symbolic reference to be made to the content of a gem.
#
# ==Gem Scheme
# When specifying a location relative to a gem, the scheme is given as 'gem:', and the hostname should
# be the name of the gem. This is all that is required if the root to use inside the gem is '<gemroot>/lib/puppet/'.
# If some other internal location should be used, it is specified as the path, and it must then be the complete
# relative path to where there are directories named 'types', 'functions', and/or possibly 'manifests'.
#
# e.g. The gem 'foo' has a type 'pineapple' located in '<gemroot>/lib/puppet/types/pops/pineapple.pp'. The
# location can then be specified with the uri 'gem://foo'. If the type instead is found under
# '<gemroot>/lin/foo/puppet/types/pops/pineapple.pp', the uri should be specified as 'gem://foo/lib/foo'.
#
# A search for a type will take place in the given order among the locations passed when instantiating
# the system loader. The first found will be used.
# If a name matches a file, it is expected to produce the given name when evaluated or an exception is raised.
#
# NOTE: Currently the search is limited to 'puppet/types/pops' and 'puppet/functions/pops'
# under a given location, and only for .pp
# file extension. TODO: This can be extended to allow other types of things to be loaded such as
# an .ecore model, content from .zip or .jar files, or .rb
#
# NOTE: A Loader could be extended with other schemes, if remote fetching is wanted; i.e. download using
# http, https, etc. If this is done, a temporary location is required (to evaluate the file), and its
# origin must then be passed to the evaluator as the temporary location would be meaningless to users
# in error messages (the current method does not take an additional 'origin' which would be required).
#
class SystemLoader < Puppet::Pops::Impl::Loader::BaseLoader
  include Puppet::Pops::Impl::Loaders::UriHelper
  include Puppet::Pops::API::Utils
  Utils = Puppet::Pops::API::Utils

  # TODO: Possibly search in more locations, more suffixes
  Subpaths = %w{/types /functions /manifests}
  Suffixes = %w{.pp}
  DefaultGemPath = '/lib/puppet'

  def initialize parent_loader, *locations
    super parent_loader
    @locations = configure_locations(locations)
    @miss_cache = Set.new # prevents scanning file system multiple times
    @loaded_files = Set.new # prevent files from being loaded again
  end

  def find(name, executor)
    name = Utils.relativize_name(name)
    return nil if @miss_cache.include?(name)

    # Turn name into a relative path.
    # Structured type name not possible in 3x, but this makes it possible
    namepath = File.join(Utils.relativize_name(name).downcase.split('::'))
    # find a file that match, pick the first found
    # TODO: Improve readability, Use DIR and {x,y} alternatives instead
    file = @locations.product(Subpaths, [namepath], Suffixes).find {|f| File.exists?(File.join(f[0..-2])+f[-1]) }
    if file
      unless @loaded_files.include? f
        executor.run_file(f, self)
        @loaded_files.add(f)
        # do not give up here if not found, in the future there may be fragments/extensions to search
      end

      # File is expected to define the name when evaluated
      executor.run_file(file, self)
      if loaded = self[name]
        loaded
      else
        @miss_cache.add(name)
        raise "TODO TYPE: Loading of file #{file}, did not produce the expected named element: #{name}"
      end
    else
      @miss_cache.add(name)
      nil # name is not found here (no matching file name found)
    end
  end

  private

  def configure_locations(locations)
    raise "TODO TYPE: A system loader must be given at least one location to load from" unless locations.size > 0
    locations = locations.flatten # varargs or array passed
    # Turn into a valid URI - or throw exception (this to force interpretation of files etc. into
    # a common form.
    result = locations.collect {|loc| path_for_uri(URI(loc), DefaultGemPath) }
    # Verify they exists
    unless (rejected = locations.reject {|path| !File.directory?(path) }).empty?
     raise "TODO TYPE: Loader can not load from the directories (not directory): #{rejected}"
    end
    result
  end

end
end; end; end; end