# Methods to help with handling warnings.
module Puppet::Util::Warnings
  module_function

  def notice_once(msg)
    Puppet::Util::Warnings.maybe_log(msg, self.class) { Puppet.notice msg }
  end

  def debug_once(msg)
    return nil unless Puppet[:debug]
    Puppet::Util::Warnings.maybe_log(msg, self.class) { Puppet.debug msg }
  end

  def warnonce(msg)
    Puppet::Util::Warnings.maybe_log(msg, self.class) { Puppet.warning msg }
  end

  def clear_warnings
    @stampwarnings = {}
    nil
  end

  protected

  def self.maybe_log(message, klass)
    @stampwarnings ||= {}
    @stampwarnings[klass] ||= []
    return nil if @stampwarnings[klass].include? message
    yield
    @stampwarnings[klass] << message
    nil
  end
end
