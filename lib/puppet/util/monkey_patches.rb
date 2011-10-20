
unless defined? JRUBY_VERSION
  Process.maxgroups = 1024
end

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
  def <=> (other)
    self.to_s <=> other.to_s
  end
end

[Object, Exception, Integer, Struct, Date, Time, Range, Regexp, Hash, Array, Float, String, FalseClass, TrueClass, Symbol, NilClass, Class].each { |cls|
  cls.class_eval do
    def to_yaml(ignored=nil)
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

class Object
  # ActiveSupport 2.3.x mixes in a dangerous method
  # that can cause rspec to fork bomb
  # and other strange things like that.
  def daemonize
    raise NotImplementedError, "Kernel.daemonize is too dangerous, please don't try to use it."
  end

  # The following code allows callers to make assertions that are only
  # checked when the environment variable PUPPET_ENABLE_ASSERTIONS is
  # set to a non-empty string.  For example:
  #
  #   assert_that { condition }
  #   assert_that(message) { condition }
  if ENV["PUPPET_ENABLE_ASSERTIONS"].to_s != ''
    def assert_that(message = nil)
      unless yield
        raise Exception.new("Assertion failure: #{message}")
      end
    end
  else
    def assert_that(message = nil)
    end
  end
end

# Workaround for yaml_initialize, which isn't supported before Ruby
# 1.8.3.
if RUBY_VERSION == '1.8.1' || RUBY_VERSION == '1.8.2'
  YAML.add_ruby_type( /^object/ ) { |tag, val|
    type, obj_class = YAML.read_type_class( tag, Object )
    r = YAML.object_maker( obj_class, val )
    if r.respond_to? :yaml_initialize
      r.instance_eval { instance_variables.each { |name| remove_instance_variable name } }
      r.yaml_initialize(tag, val)
    end
    r
  }
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

  alias :count :length unless method_defined? :count
end


class Symbol
  def to_proc
    Proc.new { |*args| args.shift.__send__(self, *args) }
  end unless method_defined? :to_proc
end


class String
  def lines(separator = $/)
    lines = split(separator)
    block_given? and lines.each {|line| yield line }
    lines
  end
end

class IO
  def lines(separator = $/)
    lines = split(separator)
    block_given? and lines.each {|line| yield line }
    lines
  end
end
