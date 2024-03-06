# frozen_string_literal: true

#
# Simple module for logging messages on the client-side

module Puppet
  Type.newtype(:notify) do
    @doc = "Sends an arbitrary message, specified as a string, to the agent run-time log. It's important to note that the notify resource type is not idempotent. As a result, notifications are shown as a change on every Puppet run."

    apply_to_all

    newproperty(:message, :idempotent => false) do
      desc "The message to be sent to the log. Note that the value specified must be a string."
      def sync
        message = @sensitive ? 'Sensitive [value redacted]' : should
        case @resource["withpath"]
        when :true
          send(@resource[:loglevel], message)
        else
          Puppet.send(@resource[:loglevel], message)
        end
        nil
      end

      def retrieve
        :absent
      end

      def insync?(is)
        false
      end

      defaultto { @resource[:name] }
    end

    newparam(:withpath) do
      desc "Whether to show the full object path."
      defaultto :false

      newvalues(:true, :false)
    end

    newparam(:name) do
      desc "An arbitrary tag for your own reference; the name of the message."
      isnamevar
    end
  end
end
