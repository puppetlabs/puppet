require 'spec_helper'
require 'webrick'
require "webrick/ssl"

class PuppetSpec::Puppetserver
  include PuppetSpec::Fixtures
  include PuppetSpec::Files

  attr_reader :ca_cert, :ca_crl, :server_cert, :server_key

  class NodeServlet < WEBrick::HTTPServlet::AbstractServlet
    def do_GET request, response
      node = Puppet::Node.new(Puppet[:certname])
      response.body = node.render(:json)
      response['Content-Type'] = 'application/json'
    end
  end

  class CatalogServlet < WEBrick::HTTPServlet::AbstractServlet
    def do_POST request, response
      response['Content-Type'] = 'application/json'
      response['X-Puppet-Compiler-Name'] = 'test-compiler-hostname'
      catalog = Puppet::Resource::Catalog.new(Puppet[:certname], 'production')
      response.body = catalog.render(:json)
    end
  end

  class FileMetadatasServlet < WEBrick::HTTPServlet::AbstractServlet
    def do_GET request, response
      response['Content-Type'] = 'application/json'
      response.body = "[{\"path\":\"/etc/puppetlabs/code/environments/production/modules\",\"relative_path\":\".\",\"links\":\"follow\",\"owner\":0,\"group\":0,\"mode\":493,\"checksum\":{\"type\":\"ctime\",\"value\":\"{ctime}2020-03-06 20:14:25 UTC\"},\"type\":\"directory\",\"destination\":null}]"
    end
  end

  class FileMetadataServlet < WEBrick::HTTPServlet::AbstractServlet
    def do_GET request, response
      response['Content-Type'] = 'application/json'
      response.body = "{\"path\":\"/etc/puppetlabs/code/environments/production/modules\",\"relative_path\":\".\",\"links\":\"follow\",\"owner\":0,\"group\":0,\"mode\":493,\"checksum\":{\"type\":\"ctime\",\"value\":\"{ctime}2020-03-06 20:14:25 UTC\"},\"type\":\"directory\",\"destination\":null}"
    end
  end

  class FileContentServlet < WEBrick::HTTPServlet::AbstractServlet
    def do_GET request, response
      response.status = 404
    end
  end

  class ReportServlet < WEBrick::HTTPServlet::AbstractServlet
    def do_PUT request, response
      response['Content-Type'] = 'application/json'
      response.body = "[]"
    end
  end

  class StaticFileContentServlet < WEBrick::HTTPServlet::AbstractServlet
    def do_GET request, response
      response.status = 404
    end
  end

  class FilebucketServlet < WEBrick::HTTPServlet::AbstractServlet
    def do_GET request, response
    end

    def do_PUT request, response
      upload = File.join(@config.config[:TempDir], 'filebucket')
      File.open(upload, 'wb') { |f| f.write(request.body) }
      response['Content-Type'] = 'application/octet-stream'
    end

    def do_HEAD request, response
      response.status = 404
    end
  end

  class CertificateServlet < WEBrick::HTTPServlet::AbstractServlet
    def initialize(server, ca_cert)
      super(server)
      @ca_cert = ca_cert
    end

    def do_GET request, response
      if request.path =~ %r{/puppet-ca/v1/certificate/ca$}
        response['Content-Type'] = 'text/plain'
        response.body = @ca_cert.to_pem
      else
        response.status = 404
      end
    end
  end

  class CertificateRevocationListServlet < WEBrick::HTTPServlet::AbstractServlet
    def initialize(server, crl)
      super(server)
      @crl = crl
    end

    def do_GET request, response
      response['Content-Type'] = 'text/plain'
      response.body = @crl.to_pem
    end
  end

  class CertificateRequestServlet < WEBrick::HTTPServlet::AbstractServlet
    def do_PUT request, response
      response.status = 404
    end
  end

  def initialize
    @ca_cert = cert_fixture('ca.pem')
    @ca_crl = crl_fixture('crl.pem')
    @server_key = key_fixture('127.0.0.1-key.pem')
    @server_cert = cert_fixture('127.0.0.1.pem')
    @path = tmpfile('webrick')

    @https = WEBrick::HTTPServer.new(
      BindAddress: "127.0.0.1",
      Port: 0, # webrick will choose the first available port, and set it in the config
      SSLEnable: true,
      SSLStartImmediately: true,
      SSLCACertificateFile: File.join(PuppetSpec::FIXTURE_DIR, 'ssl', 'ca.pem'),
      SSLCertificate: @server_cert,
      SSLPrivateKey: @server_key,
      Logger: WEBrick::Log.new(@path),
      AccessLog: [
        [@path, WEBrick::AccessLog::COMBINED_LOG_FORMAT],
      ]
    )

    trap('INT') do
      @https.shutdown
    end

    # Enable this line for more detailed webrick logging
    # @https.logger.level = 5 # DEBUG
  end

  def start_server(mounts: {}, &block)
    register_mounts(mounts: mounts)

    Thread.new do
      @https.start
    end

    begin
      yield @https.config[:Port]
    ensure
      @https.shutdown
    end
  end

  def register_mounts(mounts: {})
    register_mount('/status/v1/simple/server', proc { |req, res|  }, nil)
    register_mount('/puppet/v3/node', mounts[:node], NodeServlet)
    register_mount('/puppet/v3/catalog', mounts[:catalog], CatalogServlet)
    register_mount('/puppet/v3/file_metadata', mounts[:file_metadata], FileMetadataServlet)
    register_mount('/puppet/v3/file_metadatas', mounts[:file_metadatas], FileMetadatasServlet)
    register_mount('/puppet/v3/file_content', mounts[:file_content], FileContentServlet)
    register_mount('/puppet/v3/static_file_content', mounts[:static_file_content], StaticFileContentServlet)
    register_mount('/puppet/v3/report', mounts[:report], ReportServlet)
    register_mount('/puppet/v3/file_bucket_file', mounts[:filebucket], FilebucketServlet)
    register_mount('/puppet-ca/v1/certificate', mounts[:certificate], CertificateServlet, @ca_cert)
    register_mount('/puppet-ca/v1/certificate_revocation_list', mounts[:certificate_revocation_list], CertificateRevocationListServlet, @ca_crl)
    register_mount('/puppet-ca/v1/certificate_request', mounts[:certificate_request], CertificateRequestServlet)
  end

  def register_mount(path, user_proc, default_servlet, *args)
    handler = if user_proc
                WEBrick::HTTPServlet::ProcHandler.new(user_proc)
              else
                default_servlet
              end
    @https.mount(path, handler, *args)
  end

  def upload_directory
    @https.config[:TempDir]
  end
end
