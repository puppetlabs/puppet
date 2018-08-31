require 'spec_helper'
require 'puppet/application/ssl'
require 'webmock/rspec'

describe Puppet::Application::Ssl do
  let(:ssl) { Puppet::Application[:ssl] }
  let(:ca) do <<-PEM
-----BEGIN CERTIFICATE-----
MIIFaTCCA1GgAwIBAgIBATANBgkqhkiG9w0BAQsFADAfMR0wGwYDVQQDDBRQdXBw
ZXQgQ0E6IGxvY2FsaG9zdDAeFw0xODA4MTQxOTA5MThaFw0yMzA4MTQxOTA5MTha
MB8xHTAbBgNVBAMMFFB1cHBldCBDQTogbG9jYWxob3N0MIICIjANBgkqhkiG9w0B
AQEFAAOCAg8AMIICCgKCAgEAvE0wIzE2Bpu9DzUKgqnSXnRjelrEuEOcyE6A3dcX
vZftBFvch29WCKfFOyc0TKuAse2FGAPar1RB27+gCzb/egjPLRxZSBksW4McBdvb
8RNBHitrBGEcwsgr9I/6lx2fEWCBxUuJs390TQDwr7KSuq1JV9qL269bDkQyOOZo
4Z/puHKHP2jRupMA1MTpJO3ZLT6ks16FyJMifLDYoLUorpLon6sedmB9urAXH8D2
/TuFnvpzPDn3ZqX53BpUyNvqSn+ZxlFtMwr9csiCfBFesXX67U2D2zjIzyxZ14o0
ukhl4dHz3Gb/s/71RfCoKT1bIKFqeopl7ZYM/FTOcl0YkRQc90R5opu8RxVdUZ13
GbdFGLJ8BJNZCvhRdAVl3n9trh8PhNvq0E15ne/atjBF2fShj7C4+zqpAcQpMQwY
m9az6NKZovC+jIdzDx/6de7JdEzgmU64vEMlWzth0s+dXhLWyVLzdiEPi4kyb+yH
6/CruOB8zh6C71WfRaj28wbcK5KmGcMMOGKU53HaaFJ5gQ8FIvcjXiCfJ6f8OXpn
Wq64SmllJexWOnb3NIW3Uda1mVkJ7MJDQJMSdyd2KgQn4DffCMXtX9mJqi3Tvqd0
e1ZymE8ntNORiWWWQeXrOg4ykbHvuLM6Wi1n+5s4AlEnIOs4424H32seOk82Qrv7
/zsCAwEAAaOBrzCBrDA3BglghkgBhvhCAQ0EKgwoUHVwcGV0IFJ1YnkvT3BlblNT
TCBJbnRlcm5hbCBDZXJ0aWZpY2F0ZTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/
BAUwAwEB/zAdBgNVHQ4EFgQUy+eTVdPJf/oGx+at3UC77aNa2PQwMQYDVR0jBCow
KKEjpCEwHzEdMBsGA1UEAwwUUHVwcGV0IENBOiBsb2NhbGhvc3SCAQEwDQYJKoZI
hvcNAQELBQADggIBAHlfauetY8Cun4DBPdFyB/YlgmtCExT9TfGlKUYtZmuzM+dL
YujirGfMsmkgaA9+uAoBhi4XDcLZ+VdvO9HGZRKfKMRToL41nXBvaACmtOAF0o51
EsbjP8T66KQhWLLSHI6H91L8nR7jtXT9LYSNEF0aIz9sEyuyt4BsYBoLis/xeTBS
PXENDI8FQPSGqwWGm8RuMYelg8+IqMh1R0FNC1whw1vwDxps+iUM3JeGJrrcCG3Y
9KbpqAMBKY5Y0ESZd56uEsOh9WW8floEHhNUQh0tFn2DcqGeDOOelyXdmBdB28y+
PrgaSvq1XktDBGgTCuDuSNTsFhddVjI41QjYKPZtNt39CSVzp+egrl/CkgGekS/2
WnadaJgvNfPVnAsJTSs0/3hZlzp5MZZ2hXVA1sGrfKPYVXXLANXifHqUZToHzZ4i
EW9K8GQFTocVglS42FLVyAVVv4MHN41TMC9M0H79CINMS8e3qqZaaZQz1a1jZ9nO
5CrxUct82H220Usy8/30+xB+5dAg8ja4eRRBibVXsUO+Wi1Fd+eM3LlRhyk1fuJS
f+f91Qei36uoggVJV1S5zkq8Qfv7hcm9RElLnJQjvlkbQYhTZcSCaZ5NUSdiDbAI
WTKH/Z63t/fICwy2ORdxUz58Cp6W6TTxgfm9s/k2MPqGQIKaanaD/z53lC/a
-----END CERTIFICATE-----
PEM
  end

  let(:crl) do
    <<-PEM
-----BEGIN X509 CRL-----
MIICmTCBggIBATANBgkqhkiG9w0BAQsFADAfMR0wGwYDVQQDDBRQdXBwZXQgQ0E6
IGxvY2FsaG9zdBcNMTgwODE1MTkwOTE3WhcNMjMwODE0MTkwOTE4WqAvMC0wHwYD
VR0jBBgwFoAUy+eTVdPJf/oGx+at3UC77aNa2PQwCgYDVR0UBAMCAQAwDQYJKoZI
hvcNAQELBQADggIBAHTanPAGJclIy4BurFqxKw3I9lC4jwPQOSIrcQRtTCwrl6Rv
yb5mlPF11SxTpLLhlK1JKM1kJoGWbhR4n2ICiV+eQQb9iXZzH25oGA8zMVVh4F2V
NbZ2Ppnn9xqFhnax5Ytq2IGfgTGGTP24EgmgcAVNtBXB/TJO/EBxMpWn8v0u4lUG
4TplmoA+Zs23hXstCGakmgvyiTT5WtmnmVSlIon6EvXdUrlX1aBNx+HlIpgUUVMO
RrO4WV1rtwOAw+lYRosFOKnLGi6oDqku4kbQl4GzFUlFxnS/Xdz9PGHq8O4dNt6E
zKcAKhH51OwrP6ODbWwjIQSy393JP/uXcpQzv2Xts7J/Pn+BlHwTse6B4TfbKDQO
SsPsoFjaVQtMUCmYX+VsBBJNKAT4oFsXMz8/V8pU56P2N24sk3vUiHL5+RjA2rN6
nn6IUq7lFUOzD8P3Bx+hiCqk85FxO1A5MkpgG7gWEoQ5x5UYjGDMFjNw724Um+sY
66aPl6QwNU7nlmg/T1agplczIjekuf/DuxjniZ7B1S9hLNqRTifqYE9QirRDSB8S
oPVq5O006EMHQcNiRVEiGQGTS8wCDMDjTv8uCSxaO1nuiBpdZy8SXPC6g9s1j1SR
GZtYhcGxplP9xw03WU5Smzdepo765oA2+gFLAqGaZLXiUk091JawjWUO65Eg
-----END X509 CRL-----
PEM
  end

  before do
    WebMock.disable_net_connect!

    Puppet.settings.use(:main)

    # Host assumes ca cert and crl are present
    File.open(Puppet[:localcacert], 'w') { |f| f.write(ca) }
    File.open(Puppet[:hostcrl], 'w') { |f| f.write(crl) }
  end

  context 'when generating help' do
    it 'prints usage when no arguments are specified' do
      ssl.command_line.args << 'whoops'

      expect {
        expect {
          ssl.run_command
        }.to exit_with(1)
      }.to output(/Unknown action 'whoops'/).to_stdout
    end

    it 'rejects unknown actions' do
      expect {
        expect {
          ssl.run_command
        }.to exit_with(1)
      }.to output(/^puppet-ssl.*SYNOPSIS/m).to_stdout
    end
  end

  context 'when submitting a CSR' do
    let(:name) { 'ssl-client' }
    let(:csr_path) { File.join(Puppet[:requestdir], "#{name}.pem") }

    before do
      Puppet[:certname] = name
      ssl.command_line.args << 'submit_request'
    end

    it 'downloads the CA bundle first when missing' do
      File.delete(Puppet[:localcacert])
      stub_request(:get, %r{puppet-ca/v1/certificate/ca}).to_return(status: 200, body: ca)
      stub_request(:put, %r{puppet-ca/v1/certificate_request}).to_return(status: 200)

      expect {
        ssl.run_command
      }.to output.to_stdout
      expect(File.read(Puppet[:localcacert])).to eq(ca)
    end

    it 'downloads the CRL bundle first when missing' do
      File.delete(Puppet[:hostcrl])
      stub_request(:get, %r{puppet-ca/v1/certificate_revocation_list/ca}).to_return(status: 200, body: crl)
      stub_request(:put, %r{puppet-ca/v1/certificate_request}).to_return(status: 200)

      expect {
        ssl.run_command
      }.to output.to_stdout
      expect(File.read(Puppet[:hostcrl])).to eq(crl)
    end

    it 'submits the CSR and saves it locally' do
      stub_request(:put, %r{puppet-ca/v1/certificate_request}).to_return(status: 200)

      expect {
        ssl.run_command
      }.to output(%r{Submitted certificate request for '#{name}' to https://.*}).to_stdout

      expect(Puppet::FileSystem).to be_exist(csr_path)
    end

    it 'reports an error if the CSR has already been submitted' do
      body = "#{name} already has a requested certificate; ignoring certificate request"
      stub_request(:put, %r{puppet-ca/v1/certificate_request})
        .to_return(status: 400, body: body)

      expect {
        expect {
          ssl.run_command
        }.to exit_with(1)
      }.to output(/Failed to submit certificate request: Error 400 on SERVER: #{body}/).to_stdout
    end

    it 'accepts dns alt names'
    it 'accepts csr attributes'
    it 'accepts extension requests'
  end
end
