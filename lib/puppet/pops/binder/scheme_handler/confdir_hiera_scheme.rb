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
    # Skip if optional and does not exist
    # Skip if a hiera 1
    #
    # TODO: handle optional
    [uri]
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
end
