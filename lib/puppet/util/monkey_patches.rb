module Puppet::Util::MonkeyPatches
end

begin
  Process.maxgroups = 1024
rescue NotImplementedError
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

class Symbol
  def <=> (other)
    if (other.class != Symbol)
      case Puppet[:strict]
      when :warning
        Puppet.warn_once('deprecation', 'symbol_comparison', 'Comparing Symbols to non-Symbol values is deprecated')
      when :error
        raise ArgumentError.new("Comparing Symbols to non-Symbol values is no longer allowed")
      end
    end
    self.to_s <=> other.to_s
  end

  def intern
    self
  end unless method_defined? 'intern'
end

class Object
  # ActiveSupport 2.3.x mixes in a dangerous method
  # that can cause rspec to fork bomb
  # and other strange things like that.
  def daemonize
    raise NotImplementedError, "Kernel.daemonize is too dangerous, please don't try to use it."
  end
end

require 'fcntl'
class IO
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

# (#19151) Reject all SSLv2 ciphers and handshakes
require 'openssl'
class OpenSSL::SSL::SSLContext
  if DEFAULT_PARAMS[:options]
    DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_NO_SSLv2 | OpenSSL::SSL::OP_NO_SSLv3
  else
    DEFAULT_PARAMS[:options] = OpenSSL::SSL::OP_NO_SSLv2 | OpenSSL::SSL::OP_NO_SSLv3
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
    @puppet_certs_loaded = false
    alias __original_set_default_paths set_default_paths
    def set_default_paths
      # This can be removed once openssl integrates with windows
      # cert store, see https://rt.openssl.org/Ticket/Display.html?id=2158
      unless @puppet_certs_loaded
        @puppet_certs_loaded = true

        Puppet::Util::Windows::RootCerts.instance.to_a.uniq { |cert| cert.to_der }.each do |x509|
          begin
            add_cert(x509)
          rescue OpenSSL::X509::StoreError => e
            warn "Failed to add #{x509.subject.to_s}"
          end
        end
      end

      __original_set_default_paths
    end
  end
end
