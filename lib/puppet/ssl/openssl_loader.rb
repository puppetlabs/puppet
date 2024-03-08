# frozen_string_literal: true

require_relative '../../puppet/util/platform'

# This file should be required instead of writing `require 'openssl'`
# or any library that loads openssl like `net/https`. This allows the
# core Puppet code to load correctly in JRuby environments that do not
# have a functioning openssl (eg a FIPS enabled one).

if Puppet::Util::Platform.jruby_fips?
  # Even in JRuby we need to define the constants that are wrapped in
  # Indirections: Puppet::SSL::{Key, Certificate, CertificateRequest}
  module OpenSSL
    module PKey
      class RSA; end
    end

    module X509
      class Request; end
      class Certificate; end
    end
  end
else
  require 'openssl'
  require 'net/https'
end
