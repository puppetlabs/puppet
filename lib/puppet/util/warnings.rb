# Methods to help with handling warnings.
module Puppet::Util::Warnings
    module_function

    def notice_once(msg)
        Puppet::Util::Warnings.maybe_log(msg, self.class) { Puppet.notice msg }
    end


    def warnonce(msg)
        Puppet::Util::Warnings.maybe_log(msg, self.class) { Puppet.warning msg }
    end

    def clear_warnings()
        @stampwarnings = {}
        return nil
    end

    protected

    def self.maybe_log(message, klass)
        @stampwarnings ||= {}
        @stampwarnings[klass] ||= []
        return nil if @stampwarnings[klass].include? message
        yield
        @stampwarnings[klass] << message
        return nil
    end
end
