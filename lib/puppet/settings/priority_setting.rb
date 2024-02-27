# frozen_string_literal: true

require_relative '../../puppet/settings/base_setting'

# A setting that represents a scheduling priority, and evaluates to an
# OS-specific priority level.
class Puppet::Settings::PrioritySetting < Puppet::Settings::BaseSetting
  PRIORITY_MAP =
    if Puppet::Util::Platform.windows?
      require_relative '../../puppet/util/windows/process'
      require_relative '../../puppet/ffi/windows/constants'
      {
        :high => Puppet::FFI::Windows::Constants::HIGH_PRIORITY_CLASS,
        :normal => Puppet::FFI::Windows::Constants::NORMAL_PRIORITY_CLASS,
        :low => Puppet::FFI::Windows::Constants::BELOW_NORMAL_PRIORITY_CLASS,
        :idle => Puppet::FFI::Windows::Constants::IDLE_PRIORITY_CLASS
      }
    else
      {
        :high => -10,
        :normal => 0,
        :low => 10,
        :idle => 19
      }
    end

  def type
    :priority
  end

  def munge(value)
    return unless value

    if value.is_a?(Integer)
      value
    elsif value.is_a?(String) and value =~ /\d+/
      value.to_i
    elsif value.is_a?(String) and PRIORITY_MAP[value.to_sym]
      PRIORITY_MAP[value.to_sym]
    else
      raise Puppet::Settings::ValidationError, _("Invalid priority format '%{value}' for parameter: %{name}") % { value: value.inspect, name: @name }
    end
  end
end
