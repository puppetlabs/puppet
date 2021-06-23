require 'spec_helper'

describe "puppet ssl", unless: Puppet::Util::Platform.jruby? do
  context "print" do
    it 'translates custom oids to their long name' do
      basedir = File.expand_path("#{__FILE__}/../../../fixtures/ssl")
      # registering custom oids changes global state, so shell out
      output =
        %x{puppet ssl show \
           --certname oid \
           --localcacert #{basedir}/ca.pem \
           --hostcrl #{basedir}/crl.pem \
           --hostprivkey #{basedir}/oid-key.pem \
           --hostcert #{basedir}/oid.pem \
           --trusted_oid_mapping_file #{basedir}/trusted_oid_mapping.yaml 2>&1
        }
      expect(output).to match(/Long name:/)
    end
  end
end
