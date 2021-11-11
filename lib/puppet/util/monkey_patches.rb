require_relative '../../puppet/util/platform'

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

class Object
  # ActiveSupport 2.3.x mixes in a dangerous method
  # that can cause rspec to fork bomb
  # and other strange things like that.
  def daemonize
    raise NotImplementedError, "Kernel.daemonize is too dangerous, please don't try to use it."
  end
end

if RUBY_VERSION.to_f < 3.0
  # absolute/relative were optimized to avoid chop_basename in ruby 3
  # see https://github.com/ruby/ruby/commit/39312cf4d6c2ab3f07d688ad1a467c8f84b58db0
  require 'pathname'
  class Pathname
    if File.dirname('A:') == 'A:.' # DOSish drive letter
      ABSOLUTE_PATH = /\A(?:[A-Za-z]:|#{SEPARATOR_PAT})/o
    else
      ABSOLUTE_PATH = /\A#{SEPARATOR_PAT}/o
    end
    private_constant :ABSOLUTE_PATH

    def absolute?
      ABSOLUTE_PATH.match? @path
    end

    def relative?
      !absolute?
    end
  end
end

if Puppet::Util::Platform.windows? && RUBY_VERSION.to_f < 3.0
  # from https://github.com/ruby/ruby/blob/v2_7_3/lib/tmpdir.rb#L21-L34
  require 'tmpdir'
  class Dir
    def self.tmpdir
      tmp = nil
      # can't use ENV['TMPDIR'], see PUP-11348
      [Puppet::Util.get_env('TMPDIR'), Puppet::Util.get_env('TMP'), Puppet::Util.get_env('TEMP'), @@systmpdir, '/tmp'].each do |dir|
        next if !dir
        dir = File.expand_path(dir)
        if stat = File.stat(dir) and stat.directory? and stat.writable? and # rubocop:disable Lint/AssignmentInCondition
          (!stat.world_writable? or stat.sticky?)
          tmp = dir
          break
        end rescue nil
      end
      raise ArgumentError, "could not find a temporary directory" unless tmp
      tmp
    end
  end
end

# (#19151) Reject all SSLv2 ciphers and handshakes
require_relative '../../puppet/ssl/openssl_loader'
unless Puppet::Util::Platform.jruby_fips?
  class OpenSSL::SSL::SSLContext
    if DEFAULT_PARAMS[:options]
      DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_NO_SSLv2 | OpenSSL::SSL::OP_NO_SSLv3
    else
      DEFAULT_PARAMS[:options] = OpenSSL::SSL::OP_NO_SSLv2 | OpenSSL::SSL::OP_NO_SSLv3
    end
    if DEFAULT_PARAMS[:ciphers]
      DEFAULT_PARAMS[:ciphers] << ':!SSLv2'
    end

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
end

if Puppet::Util::Platform.windows?
  require_relative '../../puppet/util/windows'

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
          rescue OpenSSL::X509::StoreError
            warn "Failed to add #{x509.subject.to_utf8}"
          end
        end
      end

      __original_set_default_paths
    end
  end
end

unless Puppet::Util::Platform.jruby_fips?
  unless OpenSSL::X509.const_defined?(:V_ERR_HOSTNAME_MISMATCH)
    OpenSSL::X509.const_set(:V_ERR_HOSTNAME_MISMATCH, 62)
  end

  # jruby-openssl doesn't support this
  unless OpenSSL::X509::Name.instance_methods.include?(:to_utf8)
    class OpenSSL::X509::Name
      def to_utf8
        # https://github.com/ruby/ruby/blob/v2_5_5/ext/openssl/ossl_x509name.c#L317
        str = to_s(OpenSSL::X509::Name::RFC2253)
        str.force_encoding(Encoding::UTF_8)
      end
    end
  end
end
