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

# (#19151) Reject all SSLv2 ciphers and handshakes
require 'openssl'
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
          rescue OpenSSL::X509::StoreError
            warn "Failed to add #{x509.subject.to_s}"
          end
        end
      end

      __original_set_default_paths
    end
  end
end

# The Enumerable#uniq method was added in Ruby 2.4.0 (https://bugs.ruby-lang.org/issues/11090)
# This is a backport to earlier Ruby versions.
#
unless Enumerable.instance_methods.include?(:uniq)
  module Enumerable
    def uniq
      result = []
      uniq_map = {}
      if block_given?
        each do |value|
          key = yield value
          next if uniq_map.has_key?(key)
          uniq_map[key] = true
          result << value
        end
      else
        each do |value|
          next if uniq_map.has_key?(value)
          uniq_map[value] = true
          result << value
        end
      end
      result
    end
  end
end
