# frozen_string_literal: true

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
  def self.caller(skip = nil)
    in_gem_wrapper = false
    Kernel.caller.reject { |call|
      in_gem_wrapper ||= call =~ /#{Regexp.escape $PROGRAM_NAME}:\d+:in `load'/
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

unless Dir.singleton_methods.include?(:exists?)
  class Dir
    def self.exists?(file_name)
      warn("Dir.exists?('#{file_name}') is deprecated, use Dir.exist? instead") if $VERBOSE
      Dir.exist?(file_name)
    end
  end
end

unless File.singleton_methods.include?(:exists?)
  class File
    def self.exists?(file_name)
      warn("File.exists?('#{file_name}') is deprecated, use File.exist? instead") if $VERBOSE
      File.exist?(file_name)
    end
  end
end

require_relative '../../puppet/ssl/openssl_loader'
unless Puppet::Util::Platform.jruby_fips?
  class OpenSSL::SSL::SSLContext
    if DEFAULT_PARAMS[:options]
      DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_NO_SSLv3
    else
      DEFAULT_PARAMS[:options] = OpenSSL::SSL::OP_NO_SSLv3
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
  class OpenSSL::X509::Store
    @puppet_certs_loaded = false
    alias __original_set_default_paths set_default_paths
    def set_default_paths
      # This can be removed once openssl integrates with windows
      # cert store, see https://rt.openssl.org/Ticket/Display.html?id=2158
      unless @puppet_certs_loaded
        @puppet_certs_loaded = true

        Puppet::Util::Windows::RootCerts.instance.to_a.uniq(&:to_der).each do |x509|
          add_cert(x509)
        rescue OpenSSL::X509::StoreError
          warn "Failed to add #{x509.subject.to_utf8}"
        end
      end

      __original_set_default_paths
    end
  end
end

unless Puppet::Util::Platform.jruby_fips?
  unless defined?(OpenSSL::X509::V_ERR_HOSTNAME_MISMATCH)
    module OpenSSL::X509
      OpenSSL::X509::V_ERR_HOSTNAME_MISMATCH = 0x3E
    end
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
