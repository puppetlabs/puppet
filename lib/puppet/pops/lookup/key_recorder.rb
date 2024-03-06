# frozen_string_literal: true

# This class defines the private API of the Lookup Key Recorder support.
# @api private
#
class Puppet::Pops::Lookup::KeyRecorder
  def initialize
  end

  # rubocop:disable Naming/MemoizedInstanceVariableName
  def self.singleton
    @null_recorder ||= new
  end
  # rubocop:enable Naming/MemoizedInstanceVariableName

  # Records a key
  # (This implementation does nothing)
  #
  def record(key)
  end
end
