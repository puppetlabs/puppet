require 'puppet/util/json_filelock'

# This module is responsible for encapsulating the logic for
#  "disabling" the puppet agent during a run; in other words,
#  keeping track of enough state to answer the question
#  "has the puppet agent been administratively disabled?"
module Puppet::Agent::Disabler
  # Let the daemon run again, freely in the filesystem.
  def enable
    disable_lockfile.unlock
  end

  # Stop the daemon from making any catalog runs.
  def disable(msg=nil)
    data = {}
    if (! msg.nil?)
      data["disabled_message"] = msg
    end
    disable_lockfile.lock(data)
  end

  def disabled?
    disable_lockfile.locked?
  end

  def disable_message
    data = disable_lockfile.lock_data
    return nil if data.nil?
    if data.has_key?("disabled_message")
      return data["disabled_message"]
    end
    nil
  end


  def disable_lockfile
    @disable_lockfile ||= Puppet::Util::JsonFilelock.new(Puppet[:agent_disabled_lockfile])

    @disable_lockfile
  end
  private :disable_lockfile
end
