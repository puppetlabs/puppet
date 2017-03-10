require 'puppet/network/authstore'
require 'puppet/util/logging'
require 'puppet/file_serving'
require 'puppet/file_serving/metadata'
require 'puppet/file_serving/content'

# Broker access to the filesystem, converting local URIs into metadata
# or content objects.
class Puppet::FileServing::Mount < Puppet::Network::AuthStore
  include Puppet::Util::Logging

  attr_reader :name

  def find(path, options)
    raise NotImplementedError
  end

  # Create our object.  It must have a name.
  def initialize(name)
    unless name =~ %r{^[-\w]+$}
      raise ArgumentError, _("Invalid mount name format '%{name}'") % { name: name }
    end
    @name = name

    super()
  end

  def search(path, options)
    raise NotImplementedError
  end

  def to_s
    "mount[#{@name}]"
  end

  # A noop.
  def validate
  end
end
