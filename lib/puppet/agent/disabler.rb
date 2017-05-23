require 'puppet/util/json_lockfile'

# This module is responsible for encapsulating the logic for
#  "disabling" the puppet agent during a run; in other words,
#  keeping track of enough state to answer the question
#  "has the puppet agent been administratively disabled?"
#
# The implementation involves writing a lockfile with JSON
#  contents, and is considered part of the public Puppet API
#  because it used by external tools such as mcollective.
#
# For more information, please see docs on the website.
#  http://links.puppet.com/agent_lockfiles
module Puppet::Agent::Disabler
  DISABLED_MESSAGE_JSON_KEY = "disabled_message"

  # Let the daemon run again, freely in the filesystem.
  def enable
    Puppet.notice _("Enabling Puppet.")
    disable_lockfile.unlock
  end

  # Stop the daemon from making any catalog runs.
  def disable(msg=nil)
    data = {}
    Puppet.notice _("Disabling Puppet.")
    if (! msg.nil?)
      data[DISABLED_MESSAGE_JSON_KEY] = msg
    end
    disable_lockfile.lock(data)
  end

  def disabled?
    disable_lockfile.locked?
  end

  def disable_message
    data = disable_lockfile.lock_data
    return nil if data.nil?
    if data.has_key?(DISABLED_MESSAGE_JSON_KEY)
      return data[DISABLED_MESSAGE_JSON_KEY]
    end
    nil
  end


  def disable_lockfile
    @disable_lockfile ||= Puppet::Util::JsonLockfile.new(Puppet[:agent_disabled_lockfile])

    @disable_lockfile
  end
  private :disable_lockfile
end
