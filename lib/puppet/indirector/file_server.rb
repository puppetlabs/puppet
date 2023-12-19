# frozen_string_literal: true

require_relative '../../puppet/file_serving/configuration'
require_relative '../../puppet/file_serving/fileset'
require_relative '../../puppet/file_serving/terminus_helper'
require_relative '../../puppet/indirector/terminus'

# Look files up using the file server.
class Puppet::Indirector::FileServer < Puppet::Indirector::Terminus
  include Puppet::FileServing::TerminusHelper

  # Is the client authorized to perform this action?
  def authorized?(request)
    return false unless [:find, :search].include?(request.method)

    mount, _ = configuration.split_path(request)

    # If we're not serving this mount, then access is denied.
    return false unless mount

    true
  end

  # Find our key using the fileserver.
  def find(request)
    mount, relative_path = configuration.split_path(request)

    return nil unless mount

    # The mount checks to see if the file exists, and returns nil
    # if not.
    path = mount.find(relative_path, request)
    return nil unless path

    path2instance(request, path)
  end

  # Search for files.  This returns an array rather than a single
  # file.
  def search(request)
    mount, relative_path = configuration.split_path(request)

    paths = mount.search(relative_path, request) if mount
    unless paths
      Puppet.info _("Could not find filesystem info for file '%{request}' in environment %{env}") % { request: request.key, env: request.environment }
      return nil
    end
    path2instances(request, *paths)
  end

  private

  # Our fileserver configuration, if needed.
  def configuration
    Puppet::FileServing::Configuration.configuration
  end
end
