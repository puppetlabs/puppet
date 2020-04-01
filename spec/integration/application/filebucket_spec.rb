require 'spec_helper'
require 'puppet/face'
require 'puppet_spec/puppetserver'
require 'puppet_spec/files'

describe "puppet filebucket" do
  include PuppetSpec::Files
  include_context "https client"

  let(:server) { PuppetSpec::Puppetserver.new }
  let(:filebucket) { Puppet::Application[:filebucket] }
  let(:backup_file) { tmpfile('backup_file') }

  before :each do
    Puppet[:log_level] = 'debug'
  end

  it "backs up files to the filebucket server" do
    File.binwrite(backup_file, 'some random text')
    md5 = Digest::MD5.file(backup_file).to_s

    server.start_server do |port|
      Puppet[:masterport] = port
      expect {
        filebucket.command_line.args << 'backup'
        filebucket.command_line.args << backup_file
        filebucket.run
      }.to output(a_string_matching(
        %r{Debug: HTTP HEAD https:\/\/127.0.0.1:#{port}\/puppet\/v3\/file_bucket_file\/md5\/#{md5}\/#{File.realpath(backup_file)} returned 404 Not Found}
      ).and matching(
        %r{Debug: HTTP PUT https:\/\/127.0.0.1:#{port}\/puppet\/v3\/file_bucket_file\/md5\/#{md5}\/#{File.realpath(backup_file)} returned 200 OK}
      ).and matching(
        %r{#{backup_file}: #{md5}}
      )).to_stdout
    end
  end

  it "doesn't attempt to back up file that already exists on the filebucket server" do
    file_exists_handler = -> (req, res) {
        res.status = 200
    }

    File.binwrite(backup_file, 'some random text')
    md5 = Digest::MD5.file(backup_file).to_s

    server.start_server(mounts: {filebucket: file_exists_handler}) do |port|
      Puppet[:masterport] = port
      expect {
        filebucket.command_line.args << 'backup'
        filebucket.command_line.args << backup_file
        filebucket.run
      }.to output(a_string_matching(
        %r{Debug: HTTP HEAD https:\/\/127.0.0.1:#{port}\/puppet\/v3\/file_bucket_file\/md5\/#{md5}\/#{File.realpath(backup_file)} returned 200 OK}
      ).and matching(
        %r{#{backup_file}: #{md5}}
      )).to_stdout
    end
  end

  it "downloads files from the filebucket server" do
    get_handler = -> (req, res) {
      res['Content-Type'] = 'application/octet-stream'
      res.body = 'something to store'
    }

    server.start_server(mounts: {filebucket: get_handler}) do |port|
      Puppet[:masterport] = port
      expect {
        filebucket.command_line.args << 'get'
        filebucket.command_line.args << 'fac251367c9e083c6b1f0f3181'
        filebucket.run
      }.to output(a_string_matching(
        %r{Debug: HTTP GET https:\/\/127.0.0.1:#{port}\/puppet\/v3\/file_bucket_file\/md5\/fac251367c9e083c6b1f0f3181 returned 200 OK}
      ).and matching(
        %r{something to store}
       )).to_stdout
    end
  end
end