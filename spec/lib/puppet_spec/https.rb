require 'spec_helper'
require 'webrick'

class PuppetSpec::HTTPSServer
  attr_reader :ca_cert, :ca_crl, :server_cert, :server_key

  def initialize
    @ca_cert = OpenSSL::X509::Certificate.new(CA_CERT)
    @ca_crl = OpenSSL::X509::CRL.new(CRL)
    @server_key = OpenSSL::PKey::RSA.new(SERVER_KEY)
    @server_cert = OpenSSL::X509::Certificate.new(SERVER_CERT)
    @config = WEBrick::Config::HTTP.dup
  end

  def handle_request(ctx, ssl)
    req = WEBrick::HTTPRequest.new(@config)
    req.parse(ssl)

    res = WEBrick::HTTPResponse.new(@config)
    res.status = 200
    res.body = 'OK'
    res.send_response(ssl)
  end

  def start_server(&block)
    errors = []

    IO.pipe {|stop_pipe_r, stop_pipe_w|
      store = OpenSSL::X509::Store.new
      store.add_cert(@ca_cert)
      store.purpose = OpenSSL::X509::PURPOSE_SSL_CLIENT
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.cert_store = store
      ctx.cert = @server_cert
      ctx.key = @server_key
      ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE

      Socket.do_not_reverse_lookup = true
      tcps = TCPServer.new("127.0.0.1", 0)
      begin
        port = tcps.connect_address.ip_port
        begin
          server_thread = Thread.new do
            begin
              ssls = OpenSSL::SSL::SSLServer.new(tcps, ctx)
              ssls.start_immediately = true

              loop do
                readable, = IO.select([ssls, stop_pipe_r])
                break if readable.include? stop_pipe_r

                ssl = ssls.accept
                begin
                  handle_request(ctx, ssl)
                ensure
                  ssl.close
                end
              end
            rescue => e
              # uncomment this line if something goes wrong
              # puts "SERVER #{e.message}"
              errors << e
            end
          end

          begin
            yield port
          ensure
            stop_pipe_w.close
          end
        ensure
          server_thread.join
        end
      ensure
        tcps.close
      end
    }

    errors
  end

CA_CERT = <<END
-----BEGIN CERTIFICATE-----
MIICMjCCAZugAwIBAgIBADANBgkqhkiG9w0BAQsFADASMRAwDgYDVQQDDAdUZXN0
IENBMB4XDTcwMDEwMTAwMDAwMFoXDTI5MDMwMTIxMzgxMVowEjEQMA4GA1UEAwwH
VGVzdCBDQTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAvPbXy4tgmUZsLx39
Q7/Fuo5cOVk9yNzwMN4000jZQjAC8DQKXSDkbJ/6MmaiRo+VgwWlEIRVttYjrXF/
YPKZowbEIaggc9uK96+HLiGiZ0H6rNM7DYsJiCX4OzJ91SOx9qsyJbyNxLbf+IP0
961sTQhsRaqLn8vsn8Mv9I87eHsCAwEAAaOBlzCBlDAPBgNVHRMBAf8EBTADAQH/
MA4GA1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUlJ+BUoL64NmMn+IAgiLokQqr0zcw
MQYJYIZIAYb4QgENBCQWIlB1cHBldCBTZXJ2ZXIgSW50ZXJuYWwgQ2VydGlmaWNh
dGUwHwYDVR0jBBgwFoAUlJ+BUoL64NmMn+IAgiLokQqr0zcwDQYJKoZIhvcNAQEL
BQADgYEAbIca4hMdGmQvLOnNIQJ+PaMsIQ9ZT6dr+NCvIf1Ass1dEr0qRy7tpyP0
scgYmnIrOHDoe+ecyvEuG1oDb/6wLCGzD4OJXRsOzqsSCZJ31HkmDircQGpd+XbR
BxqltBWaWmSBH+e64Himc1HbHRq5xb8JFRMK9dSqiF3DrREMN/A=
-----END CERTIFICATE-----
END

CRL = <<END
-----BEGIN X509 CRL-----
MIIBCjB1AgEBMA0GCSqGSIb3DQEBCwUAMBIxEDAOBgNVBAMMB1Rlc3QgQ0EXDTcw
MDEwMTAwMDAwMFoXDTI5MDMwMTIxMzgxMVqgLzAtMB8GA1UdIwQYMBaAFJSfgVKC
+uDZjJ/iAIIi6JEKq9M3MAoGA1UdFAQDAgEAMA0GCSqGSIb3DQEBCwUAA4GBAK/r
2fz+PGgDzu85Od5Tp6jH+3Ons5WURxZzpfveGcG5fgRIG274E5Q1z+Aoj9KW/J5V
6FPbuoVEpykTicKKQaALHfryOEaLqIbTPu+94AivOx9RxzHhYPrblvjuDkmVf+fp
O3/6YKoeOom3FP/ftKdcsx7tGXy8UxCMUaBGVb5J
-----END X509 CRL-----
END

SERVER_CERT = <<END
-----BEGIN CERTIFICATE-----
MIIBvzCCASigAwIBAgIBAzANBgkqhkiG9w0BAQsFADASMRAwDgYDVQQDDAdUZXN0
IENBMB4XDTcwMDEwMTAwMDAwMFoXDTI5MDMwMTIxMzgxMVowFDESMBAGA1UEAwwJ
MTI3LjAuMC4xMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDRTWFUYiB9TnI/
ByjHHWnjnA02ieuczgAgI5CzrlrQCbCiogmsyvLmcKp4zJFVPTC6eG6Xy4sXANcn
g44l5gr3wcSzYctukk05HSbbdoBK5jjAzMT6al9l4mQdVXmv6dIkPFq27rIEaJTu
pOPaLn+mq64o2+lhTLLESOxygzOlWQIDAQABoyMwITAfBgNVHREEGDAWggkxMjcu
MC4wLjGCCTEyNy4wLjAuMjANBgkqhkiG9w0BAQsFAAOBgQCNdGVATsyhgfNHe4K8
19Bi80kA6bvrNQ+6dOwNA3bfpOXog3MU+T5+Sv1tlHl7lL+fnTHZkfRzcQhA10Fw
YdAxLDyDcY4PzgQcWSw7Lu74TLucfzcR+s+MYHAy8XXP002kjCBrSoSMiQPtXF7P
f/MQaTCXjA8BP6Ldw4wdlODR5A==
-----END CERTIFICATE-----
END

SERVER_KEY = <<END
-----BEGIN RSA PRIVATE KEY-----
MIICXAIBAAKBgQDRTWFUYiB9TnI/ByjHHWnjnA02ieuczgAgI5CzrlrQCbCiogms
yvLmcKp4zJFVPTC6eG6Xy4sXANcng44l5gr3wcSzYctukk05HSbbdoBK5jjAzMT6
al9l4mQdVXmv6dIkPFq27rIEaJTupOPaLn+mq64o2+lhTLLESOxygzOlWQIDAQAB
AoGAYbM9O6aSg+uaaNFut4ODajvt7wdydD+0z0vKwBUjTvk2+rOo0H/r4qW07a6Q
KLnnhSOyfCkHRDWgOVGviQFZHHVptrxiMA6oiyWUL/CuKjGdDQi+Q1xnuEPh0qEz
Q5ELkY1amDFS0pQV0LkDOweF4rc57haJcgRFxOz2HQJKeAECQQD0csJ4/sTq7lsg
ebIFn0kKL/k99H53rUH3XlrnGo9CnVChLe6K9J/4smp98MCre0eSgc9ahNs2c4Fs
ZpcgT8mVAkEA2zFwDhSXkkcWGmfk2Q/pfj/0OqLcIGTYkvi3sc2uirHb93VOLlvj
ClM2XwRWeeeiEW+Ev5bLmHVGuK55+h/jtQJAfwTatJB9ti2gwGE79dvs0hRXiK/w
vzMSIf2vcoLEijLAYOBDIYU3Ur0yxLpDA1gNur0lB74dQlAGolM0mB+deQJBAKBf
RYsnydY+qI9dYHToTYAPrtOQANq6rjKqQ0yWHpRfmX8ulqsYk78kLu3KMLM0pMF5
BHlhDUlY1QuerKQy3NkCQENWVz2NfnrrcgXUMHBojONcP3mkkOUocO4Ezm4GAgXO
L55O+hAtuLYdxmuNPNhT2eyOsJ/pmPntS2k/rp39Hf4=
-----END RSA PRIVATE KEY-----
END

UNKNOWN_CA = <<END
-----BEGIN CERTIFICATE-----
MIIEFTCCAv2gAwIBAgIGSUEs5AAQMA0GCSqGSIb3DQEBCwUAMIGnMQswCQYDVQQGEwJIVTERMA8G
A1UEBwwIQnVkYXBlc3QxFTATBgNVBAoMDE5ldExvY2sgS2Z0LjE3MDUGA1UECwwuVGFuw7pzw610
dsOhbnlraWFkw7NrIChDZXJ0aWZpY2F0aW9uIFNlcnZpY2VzKTE1MDMGA1UEAwwsTmV0TG9jayBB
cmFueSAoQ2xhc3MgR29sZCkgRsWRdGFuw7pzw610dsOhbnkwHhcNMDgxMjExMTUwODIxWhcNMjgx
MjA2MTUwODIxWjCBpzELMAkGA1UEBhMCSFUxETAPBgNVBAcMCEJ1ZGFwZXN0MRUwEwYDVQQKDAxO
ZXRMb2NrIEtmdC4xNzA1BgNVBAsMLlRhbsO6c8OtdHbDoW55a2lhZMOzayAoQ2VydGlmaWNhdGlv
biBTZXJ2aWNlcykxNTAzBgNVBAMMLE5ldExvY2sgQXJhbnkgKENsYXNzIEdvbGQpIEbFkXRhbsO6
c8OtdHbDoW55MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxCRec75LbRTDofTjl5Bu
0jBFHjzuZ9lk4BqKf8owyoPjIMHj9DrTlF8afFttvzBPhCf2nx9JvMaZCpDyD/V/Q4Q3Y1GLeqVw
/HpYzY6b7cNGbIRwXdrzAZAj/E4wqX7hJ2Pn7WQ8oLjJM2P+FpD/sLj916jAwJRDC7bVWaaeVtAk
H3B5r9s5VA1lddkVQZQBr17s9o3x/61k/iCa11zr/qYfCGSji3ZVrR47KGAuhyXoqq8fxmRGILdw
fzzeSNuWU7c5d+Qa4scWhHaXWy+7GRWF+GmF9ZmnqfI0p6m2pgP8b4Y9VHx2BJtr+UBdADTHLpl1
neWIA6pN+APSQnbAGwIDAKiLo0UwQzASBgNVHRMBAf8ECDAGAQH/AgEEMA4GA1UdDwEB/wQEAwIB
BjAdBgNVHQ4EFgQUzPpnk/C2uNClwB7zU/2MU9+D15YwDQYJKoZIhvcNAQELBQADggEBAKt/7hwW
qZw8UQCgwBEIBaeZ5m8BiFRhbvG5GK1Krf6BQCOUL/t1fC8oS2IkgYIL9WHxHG64YTjrgfpioTta
YtOUZcTh5m2C+C8lcLIhJsFyUR+MLMOEkMNaj7rP9KdlpeuY0fsFskZ1FSNqb4VjMIDw1Z4fKRzC
bLBQWV2QWzuoDTDPv31/zvGdg73JRm4gpvlhUbohL3u+pRVjodSVh/GeufOJ8z2FuLjbvrW5Kfna
NwUASZQDhETnv0Mxz3WLJdH0pmT1kvarBes96aULNmLazAZfNou2XjG4Kvte9nHfRCaexOYNkbQu
dZWAUWpLMKawYqGT8ZvYzsRjdT9ZR7E=
-----END CERTIFICATE-----
END
end
