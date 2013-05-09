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
  def <=> (other)
    self.to_s <=> other.to_s
  end unless method_defined? '<=>'

  def intern
    self
  end unless method_defined? 'intern'
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

class Fixnum
  # Returns the int itself. This method is intended for compatibility to
  # character constant in Ruby 1.9.  1.8.5 is missing it; add it.
  def ord
    self
  end unless method_defined? 'ord'
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
  # So, it turns out that one of the biggest memory allocation hot-spots in
  # our code was using symbol-to-proc - because it allocated a new instance
  # every time it was called, rather than caching.
  #
  # Changing this means we can see XX memory reduction...
  if method_defined? :to_proc
    alias __original_to_proc to_proc
    def to_proc
      @my_proc ||= __original_to_proc
    end
  else
    def to_proc
      @my_proc ||= Proc.new {|*args| args.shift.__send__(self, *args) }
    end
  end

  # Defined in 1.9, absent in 1.8, and used for compatibility in various
  # places, typically in third party gems.
  def intern
    return self
  end unless method_defined? :intern
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

# The mv method in Ruby 1.8.5 can't mv directories across devices
# File.rename causes "Invalid cross-device link", which is rescued, but in Ruby
# 1.8.5 it tries to recover with a copy and unlink, but the unlink causes the
# error "Is a directory".  In newer Rubies remove_entry is used
# The implementation below is what's used in Ruby 1.8.7 and Ruby 1.9
if RUBY_VERSION == '1.8.5'
  require 'fileutils'

  module FileUtils
    def mv(src, dest, options = {})
      fu_check_options options, OPT_TABLE['mv']
      fu_output_message "mv#{options[:force] ? ' -f' : ''} #{[src,dest].flatten.join ' '}" if options[:verbose]
      return if options[:noop]
      fu_each_src_dest(src, dest) do |s, d|
        destent = Entry_.new(d, nil, true)
        begin
          if destent.exist?
            if destent.directory?
              raise Errno::EEXIST, dest
            else
              destent.remove_file if rename_cannot_overwrite_file?
            end
          end
          begin
            File.rename s, d
          rescue Errno::EXDEV
            copy_entry s, d, true
            if options[:secure]
              remove_entry_secure s, options[:force]
            else
              remove_entry s, options[:force]
            end
          end
        rescue SystemCallError
          raise unless options[:force]
        end
      end
    end
    module_function :mv

    alias move mv
    module_function :move
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
