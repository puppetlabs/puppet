Process.maxgroups = 1024

module RDoc 
    def self.caller(skip=nil)
        in_gem_wrapper = false
        Kernel.caller.reject { |call|
            in_gem_wrapper ||= call =~ /#{Regexp.escape $0}:\d+:in `load'/
        }
    end
end


require "yaml"
require "puppet/util/zaml.rb"

class Symbol
    def to_zaml(z)
        z.emit("!ruby/sym ")
        to_s.to_zaml(z)
    end
end

class Object
    def to_yaml
        ZAML.dump(self)
    end
end

def YAML.dump(*args)
    ZAML.dump(*args)
end



