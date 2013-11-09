# Similar to {Puppet::Pops::Binder::SchemeHandler::ModuleHieraScheme ModuleHieraScheme} but path is
# relative to the `$confdir` instead of relative to a module root.
#
# Does not handle wild-cards.
# @api public
class Puppet::Pops::Binder::SchemeHandler::ConfdirHieraScheme < Puppetx::Puppet::BindingsSchemeHandler

  # (Puppetx::Puppet::BindingsSchemeHandler.contributed_bindings)
  #
  def contributed_bindings(uri, scope, composer)
    split_path = uri.path.split('/')
    name = split_path[1]
    confdir = composer.confdir
    provider = Puppet::Pops::Binder::Hiera2::BindingsProvider.new(uri.to_s, File.join(confdir, uri.path), composer.acceptor)
    provider.load_bindings(scope)
  end

  # This handler does not support wildcards.
  # The given uri is simply returned in an array.
  # @param uri [URI] the uri to expand
  # @return [Array<URI>] the uri wrapped in an array
  # @todo Handle optional and possibly hiera-1 hiera.yaml config file in the expected location (the same as missing)
  # @api public
  #
  def expand_included(uri, composer)
    result = []
    if config_exist?(uri, composer)
      result << uri unless is_ignored_hiera_version?(uri, composer)
    else
      result << uri unless is_optional?(uri)
    end
    result
  end

  # This handler does not support wildcards.
  # The given uri is simply returned in an array.
  # @param uri [URI] the uri to expand
  # @return [Array<URI>] the uri wrapped in an array
  # @api public
  #
  def expand_excluded(uri, composer)
    [uri]
  end

  def config_exist?(uri, composer)
    Puppet::FileSystem::File.exist?(File.join(composer.confdir, uri.path, 'hiera.yaml'))
  end

  # A hiera.yaml that exists, is readable, can be loaded, and does not have version >= 2 set is ignored.
  # All other conditions are reported as 'not ignored' even if there are errors; these will be handled later
  # as if the hiera.yaml is a hiera-2 file.
  # @api private
  def is_ignored_hiera_version?(uri, composer)
    config_file = File.join(composer.confdir, uri.path, 'hiera.yaml')
    begin
      data = YAML.load_file(config_file)
      if data.is_a?(Hash)
        ver = data[:version] || data['version']
        return ver.nil? || ver < 2
      end
    rescue Errno::ENOENT
    rescue Errno::ENOTDIR
    rescue ::SyntaxError => e
    end
    return false
  end
end
