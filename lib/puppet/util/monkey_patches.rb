
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
  end unless method_defined? "<=>"
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
  end unless method_defined? :lines
end

class IO
  def lines(separator = $/)
    lines = split(separator)
    block_given? and lines.each {|line| yield line }
    lines
  end unless method_defined? :lines

  def self.binread(name, length = nil, offset = 0)
    File.open(name, 'rb') do |f|
      f.seek(offset) if offset > 0
      f.read(length)
    end
  end unless singleton_methods.include?(:binread)

  def self.binwrite(name, string, offset = 0)
    File.open(name, 'wb') do |f|
      f.write(offset > 0 ? string[offset..-1] : string)
    end
  end unless singleton_methods.include?(:binwrite)
end

class Range
  def intersection(other)
    raise ArgumentError, 'value must be a Range' unless other.kind_of?(Range)
    return unless other === self.first || self === other.first

    start = [self.first, other.first].max
    if self.exclude_end? && self.last <= other.last
      start ... self.last
    elsif other.exclude_end? && self.last >= other.last
      start ... other.last
    else
      start .. [ self.last, other.last ].min
    end
  end unless method_defined? :intersection

  alias_method :&, :intersection unless method_defined? :&
end

# Ruby 1.8.5 doesn't have tap
module Kernel
  def tap
    yield(self)
    self
  end unless method_defined?(:tap)
end


########################################################################
# The return type of `instance_variables` changes between Ruby 1.8 and 1.9
# releases; it used to return an array of strings in the form "@foo", but
# now returns an array of symbols in the form :@foo.
#
# Nothing else in the stack cares which form you get - you can pass the
# string or symbol to things like `instance_variable_set` and they will work
# transparently.
#
# Having the same form in all releases of Puppet is a win, though, so we
# pick a unification and enforce than on all releases.  That way developers
# who do set math on them (eg: for YAML rendering) don't have to handle the
# distinction themselves.
#
# In the sane tradition, we bring older releases into conformance with newer
# releases, so we return symbols rather than strings, to be more like the
# future versions of Ruby are.
#
# We also carefully support reloading, by only wrapping when we don't
# already have the original version of the method aliased away somewhere.
if RUBY_VERSION[0,3] == '1.8'
  unless Object.respond_to?(:puppet_original_instance_variables)

    # Add our wrapper to the method.
    class Object
      alias :puppet_original_instance_variables :instance_variables

      def instance_variables
        puppet_original_instance_variables.map(&:to_sym)
      end
    end

    # The one place that Ruby 1.8 assumes something about the return format of
    # the `instance_variables` method is actually kind of odd, because it uses
    # eval to get at instance variables of another object.
    #
    # This takes the original code and applies replaces instance_eval with
    # instance_variable_get through it.  All other bugs in the original (such
    # as equality depending on the instance variables having the same order
    # without any promise from the runtime) are preserved. --daniel 2012-03-11
    require 'resolv'
    class Resolv::DNS::Resource
      def ==(other) # :nodoc:
        return self.class == other.class &&
          self.instance_variables == other.instance_variables &&
          self.instance_variables.collect {|name| self.instance_variable_get name} ==
          other.instance_variables.collect {|name| other.instance_variable_get name}
      end
    end
  end
end
