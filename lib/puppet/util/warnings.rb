# Methods to help with handling warnings.
module Puppet::Util::Warnings
    module_function

    def warnonce(msg)
        $stampwarnings ||= {}
        $stampwarnings[self.class] ||= []
        unless $stampwarnings[self.class].include? msg
            Puppet.warning msg
            $stampwarnings[self.class] << msg
        end

        return nil
    end

    def clear_warnings()
        $stampwarnings = {}
        return nil
    end
end

