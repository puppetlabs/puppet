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

class Symbol
  # So, it turns out that one of the biggest memory allocation hot-spots in our
  # code was using symbol-to-proc - because it allocated a new instance every
  # time it was called, rather than caching (in Ruby 1.8.7 and earlier).
  #
  # In Ruby 1.9.3 and later Symbol#to_proc does implement a cache so we skip
  # our monkey patch.
  #
  # Changing this means we can see XX memory reduction...
  if RUBY_VERSION < "1.9.3"
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
    Puppet.deprecation_warning("This is a monkey-patched implementation of IO.binread on ruby 1.8 and is deprecated. Read the file without this method as it will be removed in a future version.")
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

class Float
  INFINITY = (1.0/0.0) if defined?(Float::INFINITY).nil?
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
      Puppet::Util::Windows::RootCerts.instance.to_a.uniq.each do |x509|
        begin
          add_cert(x509)
        rescue OpenSSL::X509::StoreError => e
          warn "Failed to add #{x509.subject.to_s}"
        end
      end

      __original_set_default_paths
    end
  end
end

# Older versions of SecureRandom (e.g. in 1.8.7) don't have the uuid method
module SecureRandom
  def self.uuid
    # Copied from the 1.9.1 stdlib implementation of uuid
    ary = self.random_bytes(16).unpack("NnnnnN")
    ary[2] = (ary[2] & 0x0fff) | 0x4000
    ary[3] = (ary[3] & 0x3fff) | 0x8000
    "%08x-%04x-%04x-%04x-%04x%08x" % ary
  end unless singleton_methods.include?(:uuid)
end
