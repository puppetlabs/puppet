
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

module Enumerable
  # Use *args so we can distinguish no argument from nil.
  def count(*args)
    seq = 0
    if !args.empty?
      item = args[0]
      each { |o| seq += 1 if item == o }
    elsif block_given?
      each { |o| seq += 1 if yield(o) }
    else
      each { seq += 1 }
    end
    seq
  end unless method_defined? :count
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

# (#19151) Reject all SSLv2 ciphers and handshakes
require 'openssl'
class OpenSSL::SSL::SSLContext
  if match = /^1\.8\.(\d+)/.match(RUBY_VERSION)
    older_than_187 = match[1].to_i < 7
  else
    older_than_187 = false
  end

  alias __original_initialize initialize
  private :__original_initialize

  if older_than_187
    def initialize(*args)
      __original_initialize(*args)
      if bitmask = self.options
        self.options = bitmask | OpenSSL::SSL::OP_NO_SSLv2
      else
        self.options = OpenSSL::SSL::OP_NO_SSLv2
      end
      # These are the default ciphers in recent MRI versions.  See
      # https://github.com/ruby/ruby/blob/v1_9_3_392/ext/openssl/lib/openssl/ssl-internal.rb#L26
      self.ciphers = "ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:+LOW"
    end
  else
    if DEFAULT_PARAMS[:options]
      DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_NO_SSLv2
    else
      DEFAULT_PARAMS[:options] = OpenSSL::SSL::OP_NO_SSLv2
    end
    DEFAULT_PARAMS[:ciphers] << ':!SSLv2'

    def initialize(*args)
      __original_initialize(*args)
      params = {
        :options => DEFAULT_PARAMS[:options],
        :ciphers => DEFAULT_PARAMS[:ciphers],
      }
      set_params(params)
    end
  end
end
