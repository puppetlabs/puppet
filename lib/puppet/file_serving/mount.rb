# frozen_string_literal: true

require_relative '../../puppet/util/logging'
require_relative '../../puppet/file_serving'
require_relative '../../puppet/file_serving/metadata'
require_relative '../../puppet/file_serving/content'

# Broker access to the filesystem, converting local URIs into metadata
# or content objects.
class Puppet::FileServing::Mount
  include Puppet::Util::Logging

  attr_reader :name

  def find(path, options)
    raise NotImplementedError
  end

  # Create our object.  It must have a name.
  def initialize(name)
    unless name =~ /^[-\w]+$/
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
