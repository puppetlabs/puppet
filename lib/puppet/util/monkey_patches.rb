require 'puppet/util'
module Puppet::Util::MonkeyPatches
end

begin
  Process.maxgroups = 1024
rescue Exception
  # Actually, I just want to ignore it, since various platforms - JRuby,
  # Windows, and so forth - don't support it, but only because it isn't a
  # meaningful or implementable concept there.
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

if defined?(YAML::ENGINE) and YAML::ENGINE.yamler == 'psych'
  def Psych.safely_load(str)
    result = Psych.parse(str)
    if invalid_node = result.find { |node| node.tag =~ /!map:(.*)/ || node.tag =~ /!ruby\/hash:(.*)/ }
      raise ArgumentError, "Illegal YAML mapping found with tag #{invalid_node.tag}; please use !ruby/object:#{$1} instead"
    else
      result.to_ruby
    end
  end
else
  def YAML.safely_load(str)
    self.load(str)
  end
end

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

  # Ruby 1.8.5 lacks `drop`, which we don't want to lose.
  def drop(n)
    n = n.to_int
    raise ArgumentError, "attempt to drop negative size" if n < 0

    slice(n, length - n) or []
  end unless method_defined? :drop
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
  unless method_defined? :lines
    require 'puppet/util/monkey_patches/lines'
    include Puppet::Util::MonkeyPatches::Lines
  end
end

require 'fcntl'
class IO
  unless method_defined? :lines
    require 'puppet/util/monkey_patches/lines'
    include Puppet::Util::MonkeyPatches::Lines
  end

  def self.binread(name, length = nil, offset = 0)
    File.open(name, 'rb') do |f|
      f.seek(offset) if offset > 0
      f.read(length)
    end
  end unless singleton_methods.include?(:binread)

  def self.binwrite(name, string, offset = nil)
    # Determine if we should truncate or not.  Since the truncate method on a
    # file handle isn't implemented on all platforms, safer to do this in what
    # looks like the libc / POSIX flag - which is usually pretty robust.
    # --daniel 2012-03-11
    mode = Fcntl::O_CREAT | Fcntl::O_WRONLY | (offset.nil? ? Fcntl::O_TRUNC : 0)

    # We have to duplicate the mode because Ruby on Windows is a bit precious,
    # and doesn't actually carry over the mode.  It won't work to just use
    # open, either, because that doesn't like our system modes and the default
    # open bits don't do what we need, which is awesome. --daniel 2012-03-30
    IO.open(IO::sysopen(name, mode), mode) do |f|
      # ...seek to our desired offset, then write the bytes.  Don't try to
      # seek past the start of the file, eh, because who knows what platform
      # would legitimately blow up if we did that.
      #
      # Double-check the positioning, too, since destroying data isn't my idea
      # of a good time. --daniel 2012-03-11
      target = [0, offset.to_i].max
      unless (landed = f.sysseek(target, IO::SEEK_SET)) == target
        raise "unable to seek to target offset #{target} in #{name}: got to #{landed}"
      end

      f.syswrite(string)
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

# Ruby 1.8.6 doesn't have it either
# From https://github.com/puppetlabs/hiera/pull/47/files:
# In ruby 1.8.5 Dir does not have mktmpdir defined, so this monkey patches
# Dir to include the 1.8.7 definition of that method if it isn't already defined.
# Method definition borrowed from ruby-1.8.7-p357/lib/ruby/1.8/tmpdir.rb
unless Dir.respond_to?(:mktmpdir)
  def Dir.mktmpdir(prefix_suffix=nil, tmpdir=nil)
    case prefix_suffix
    when nil
      prefix = "d"
      suffix = ""
    when String
      prefix = prefix_suffix
      suffix = ""
    when Array
      prefix = prefix_suffix[0]
      suffix = prefix_suffix[1]
    else
      raise ArgumentError, "unexpected prefix_suffix: #{prefix_suffix.inspect}"
    end
    tmpdir ||= Dir.tmpdir
    t = Time.now.strftime("%Y%m%d")
    n = nil
    begin
      path = "#{tmpdir}/#{prefix}#{t}-#{$$}-#{rand(0x100000000).to_s(36)}"
      path << "-#{n}" if n
      path << suffix
      Dir.mkdir(path, 0700)
    rescue Errno::EEXIST
      n ||= 0
      n += 1
      retry
    end

    if block_given?
      begin
        yield path
      ensure
        FileUtils.remove_entry_secure path
      end
    else
      path
    end
  end
end

# (#19151) Reject all SSLv2 ciphers and handshakes
require 'openssl'
class OpenSSL::SSL::SSLContext
  if DEFAULT_PARAMS[:options]
    DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_NO_SSLv2
  else
    DEFAULT_PARAMS[:options] = OpenSSL::SSL::OP_NO_SSLv2
  end
  DEFAULT_PARAMS[:ciphers] << ':!SSLv2'

  alias __original_initialize initialize
  private :__original_initialize

  def initialize(*args)
    __original_initialize(*args)
    params = {
      :options => DEFAULT_PARAMS[:options],
      :ciphers => DEFAULT_PARAMS[:ciphers],
    }
    set_params(params)
  end
end

require 'puppet/util/platform'
if Puppet::Util::Platform.windows?
  require 'puppet/util/windows'
  require 'openssl'

  class OpenSSL::X509::Store
    alias __original_set_default_paths set_default_paths
    def set_default_paths
      # This can be removed once openssl integrates with windows
      # cert store, see http://rt.openssl.org/Ticket/Display.html?id=2158
      Puppet::Util::Windows::RootCerts.instance.each do |x509|
        add_cert(x509)
      end

      __original_set_default_paths
    end
  end
end

