# GemSupport offers methods to find a gem's location by name or gem://gemname URI.
#
# TODO: The Puppet 3x, uses Puppet::Util::RubyGems to do this, and obtain paths, and avoids using ::Gems
# when ::Bundler is in effect. A quick check what happens on Ruby 1.8.7 and Ruby 1.9.3 with current
# version of bundler seems to work just fine without jumping through any hoops. Hopefully the Puppet::Utils::RubyGems is
# just dealing with arcane things prior to RubyGems 1.8 that are not needed any more. To verify there is
# the need to set up a scenario where additional bundles than what Bundler allows for a given configuration are available
# and then trying to access those.
#
module Puppet::Pops::Loader::GemSupport

  # Produces the root directory of a gem given as an URI (gem://gemname/optional/path), or just the
  # gemname as a string.
  #
  def gem_dir(uri_or_string)
    case uri_or_string
    when URI
      gem_dir_from_uri(uri_or_string)
    when String
      gem_dir_from_name(uri_or_string)
    end
  end

  # Produces the root directory of a gem given as an uri, where hostname is the gemname, and an optional
  # path is appended to the root of the gem (i.e. if the reference is given to a sub-location within a gem.
  # TODO: FIND by name raises exception Gem::LoadError with list of all gems on the path
  #
  def gem_dir_from_uri(uri)
    unless spec = Gem::Specification.find_by_name(uri.hostname)
      raise ArgumentError, "Gem not found #{uri}"
    end
    # if path given append that, else append given subdir
    if uri.path.empty?
      spec.gem_dir
    else
      File.join(spec.full_gem_path, uri.path)
    end
  end

  # Produces the root directory of a gem given as a string with the gem's name.
  # TODO: FIND by name raises exception Gem::LoadError with list of all gems on the path
  #
  def gem_dir_from_name(gem_name)
    unless spec = Gem::Specification.find_by_name(gem_name)
      raise ArgumentError, "Gem not found '#{gem_name}'"
    end
    spec.full_gem_path
  end
end