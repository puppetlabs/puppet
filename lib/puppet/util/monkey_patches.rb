Process.maxgroups = 1024
module RDoc 
    def self.caller(skip=nil)
        in_gem_wrapper = false
        Kernel.caller.reject { |call|
            in_gem_wrapper ||= call =~ /#{Regexp.escape $0}:\d+:in `load'/
        }
    end
end
