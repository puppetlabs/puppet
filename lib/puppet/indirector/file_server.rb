require 'puppet/file_serving/configuration'
require 'puppet/file_serving/fileset'
require 'puppet/file_serving/terminus_helper'
require 'puppet/indirector/terminus'

# Look files up using the file server.
class Puppet::Indirector::FileServer < Puppet::Indirector::Terminus
  include Puppet::FileServing::TerminusHelper

  # Is the client authorized to perform this action?
  def authorized?(request)
    return false unless [:find, :search].include?(request.method)

    mount, file_path = configuration.split_path(request)

    # If we're not serving this mount, then access is denied.
    return false unless mount
    mount.allowed?(request.node, request.ip)
  end

  # Find our key using the fileserver.
  def find(request)
    mount, relative_path = configuration.split_path(request)

    return nil unless mount

    # The mount checks to see if the file exists, and returns nil
    # if not.
    return nil unless path = mount.find(relative_path, request)
    path2instance(request, path)
  end

  # Search for files.  This returns an array rather than a single
  # file.
  def search(request)
    mount, relative_path = configuration.split_path(request)

    unless mount and paths = mount.search(relative_path, request)
      Puppet.info "Could not find filesystem info for file '#{request.key}' in environment #{request.environment}"
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
