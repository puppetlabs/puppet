# frozen_string_literal: true
# This class defines the private API of the Lookup Key Recorder support.
# @api private
#
class Puppet::Pops::Lookup::KeyRecorder

  def initialize()
  end

  def self.singleton
    @null_recorder ||= self.new
  end

  # Records a key
  # (This implementation does nothing)
  #
  def record(key)
  end
end
