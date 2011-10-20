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

[Object, Exception, Integer, Struct, Date, Time, Range, Regexp, Hash, Array, Float, String, FalseClass, TrueClass, Symbol, NilClass, Class].each { |cls|
    cls.class_eval do
        def to_yaml
            ZAML.dump(self)
        end
    end
}

def YAML.dump(*args)
    ZAML.dump(*args)
end

#
# Workaround for bug in MRI 1.8.7, see
#     http://redmine.ruby-lang.org/issues/show/2708
# for details
#
if RUBY_VERSION == '1.8.7'
    class NilClass
        def closed?
            true
        end
    end
end

class Array
  # Ruby < 1.8.7 doesn't have this method but we use it in tests
  def combination(num)
    return [] if num < 0 || num > size
    return [[]] if num == 0
    return map{|e| [e] } if num == 1
    tmp = self.dup
    self[0, size - (num - 1)].inject([]) do |ret, e|
      tmp.shift
      ret += tmp.combination(num - 1).map{|a| a.unshift(e) }
    end
  end unless method_defined? :combination
end


class Symbol
  def to_proc
    Proc.new { |*args| args.shift.__send__(self, *args) }
  end unless method_defined? :to_proc
end


class String
  alias :lines :each_line unless method_defined?(:lines)
end

class IO
  alias :lines :each_line unless method_defined? :lines
end
