require 'spec_helper'
require 'puppet/face'
require 'puppet_spec/puppetserver'
require 'puppet_spec/files'

describe "puppet filebucket", unless: Puppet::Util::Platform.jruby? do
  include PuppetSpec::Files
  include_context "https client"

  let(:server) { PuppetSpec::Puppetserver.new }
  let(:filebucket) { Puppet::Application[:filebucket] }
  let(:backup_file) { tmpfile('backup_file') }
  let(:text) { 'some random text' }
  let(:sha256) { Digest::SHA256.file(backup_file).to_s }

  before :each do
    Puppet[:log_level] = 'debug'
    File.binwrite(backup_file, text)
  end

  it "backs up to and restores from the local filebucket" do
    filebucket.command_line.args = ['backup', backup_file, '--local']
    expect {
      filebucket.run
    }.to output(/: #{sha256}/).to_stdout

    dest = tmpfile('file_bucket_restore')
    filebucket.command_line.args = ['restore', dest, sha256, '--local']
    expect {
      filebucket.run
    }.to output(/FileBucket read #{sha256}/).to_stdout

    expect(FileUtils.compare_file(backup_file, dest)).to eq(true)
  end

  it "backs up text files to the filebucket server" do
    server.start_server do |port|
      Puppet[:serverport] = port
      expect {
        filebucket.command_line.args = ['backup', backup_file]
        filebucket.run
      }.to output(a_string_matching(
        %r{Debug: HTTP HEAD https:\/\/127.0.0.1:#{port}\/puppet\/v3\/file_bucket_file\/sha256\/#{sha256}\/#{File.realpath(backup_file)}\?environment\=production returned 404 Not Found}
      ).and matching(
        %r{Debug: HTTP PUT https:\/\/127.0.0.1:#{port}\/puppet\/v3\/file_bucket_file\/sha256\/#{sha256}\/#{File.realpath(backup_file)}\?environment\=production returned 200 OK}
      ).and matching(
        %r{#{backup_file}: #{sha256}}
      )).to_stdout

      expect(File.binread(File.join(server.upload_directory, 'filebucket'))).to eq(text)
    end
  end

  it "backs up binary files to the filebucket server" do
    binary = "\xD1\xF2\r\n\x81NuSc\x00".force_encoding(Encoding::ASCII_8BIT)
    File.binwrite(backup_file, binary)

    server.start_server do |port|
      Puppet[:serverport] = port
      expect {
        filebucket.command_line.args = ['backup', backup_file]
        filebucket.run
      }.to output(a_string_matching(
        %r{Debug: HTTP HEAD https:\/\/127.0.0.1:#{port}\/puppet\/v3\/file_bucket_file/sha256/f3aee54d781e413862eb068d89661f930385cc81bbafffc68477ff82eb9bea43/}
      ).and matching(
        %r{Debug: HTTP PUT https:\/\/127.0.0.1:#{port}\/puppet\/v3\/file_bucket_file/sha256/f3aee54d781e413862eb068d89661f930385cc81bbafffc68477ff82eb9bea43/}
      )).to_stdout

      expect(File.binread(File.join(server.upload_directory, 'filebucket'))).to eq(binary)
    end
  end

  it "backs up utf-8 encoded files to the filebucket server" do
    utf8 = "\u2603".force_encoding(Encoding::UTF_8)
    File.binwrite(backup_file, utf8)

    server.start_server do |port|
      Puppet[:serverport] = port
      expect {
        filebucket.command_line.args = ['backup', backup_file]
        filebucket.run
      }.to output(a_string_matching(
        %r{Debug: HTTP HEAD https:\/\/127.0.0.1:#{port}\/puppet\/v3\/file_bucket_file/sha256/51643361c79ecaef25a8de802de24f570ba25d9c2df1d22d94fade11b4f466cc/}
      ).and matching(
        %r{Debug: HTTP PUT https:\/\/127.0.0.1:#{port}\/puppet\/v3\/file_bucket_file/sha256/51643361c79ecaef25a8de802de24f570ba25d9c2df1d22d94fade11b4f466cc/}
      )).to_stdout

      expect(File.read(File.join(server.upload_directory, 'filebucket'), encoding: 'utf-8')).to eq(utf8)
    end
  end

  it "doesn't attempt to back up file that already exists on the filebucket server" do
    file_exists_handler = -> (req, res) {
      res.status = 200
    }

    server.start_server(mounts: {filebucket: file_exists_handler}) do |port|
      Puppet[:serverport] = port
      expect {
        filebucket.command_line.args = ['backup', backup_file]
        filebucket.run
      }.to output(a_string_matching(
        %r{Debug: HTTP HEAD https:\/\/127.0.0.1:#{port}\/puppet\/v3\/file_bucket_file\/sha256\/#{sha256}\/#{File.realpath(backup_file)}\?environment\=production returned 200 OK}
      ).and matching(
        %r{#{backup_file}: #{sha256}}
      )).to_stdout
    end
  end

  it "downloads files from the filebucket server" do
    get_handler = -> (req, res) {
      res['Content-Type'] = 'application/octet-stream'
      res.body = 'something to store'
    }

    server.start_server(mounts: {filebucket: get_handler}) do |port|
      Puppet[:serverport] = port
      expect {
        filebucket.command_line.args = ['get', 'fac251367c9e083c6b1f0f3181']
        filebucket.run
      }.to output(a_string_matching(
        %r{Debug: HTTP GET https:\/\/127.0.0.1:#{port}\/puppet\/v3\/file_bucket_file\/sha256\/fac251367c9e083c6b1f0f3181\?environment\=production returned 200 OK}
      ).and matching(
        %r{something to store}
       )).to_stdout
    end
  end

  context 'diff', unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
    context 'using a remote bucket' do
      it 'outputs a diff between a local and remote file' do
        File.binwrite(backup_file, "bar\nbaz")

        get_handler = -> (req, res) {
          res['Content-Type'] = 'application/octet-stream'
          res.body = 'foo'
        }

        server.start_server(mounts: {filebucket: get_handler}) do |port|
          Puppet[:serverport] = port
          expect {
            filebucket.command_line.args = ['diff', 'fac251367c9e083c6b1f0f3181', backup_file, '--remote']
            filebucket.run
          }.to output(a_string_matching(
            /[-<] ?foo/
          ).and matching(
            /[+>] ?bar/
          ).and matching(
            /[+>] ?baz/
          )).to_stdout
        end
      end

      it 'outputs a diff between two remote files' do
        get_handler = -> (req, res) {
          res['Content-Type'] = 'application/octet-stream'
          res.body = <<~END
          --- /opt/puppetlabs/server/data/puppetserver/bucket/d/3/b/0/7/3/8/4/d3b07384d113edec49eaa6238ad5ff00/contents\t2020-04-06 21:25:24.892367570 +0000
          +++ /opt/puppetlabs/server/data/puppetserver/bucket/9/9/b/9/9/9/2/0/99b999207e287afffc86c053e5693247/contents\t2020-04-06 21:26:13.603398063 +0000
          @@ -1 +1,2 @@
          -foo
          +bar
          +baz
          END
        }

        server.start_server(mounts: {filebucket: get_handler}) do |port|
          Puppet[:serverport] = port
          expect {
            filebucket.command_line.args = ['diff', 'd3b07384d113edec49eaa6238ad5ff00', "99b999207e287afffc86c053e5693247", '--remote']
            filebucket.run
          }.to output(a_string_matching(
            /[-<] ?foo/
          ).and matching(
            /[+>] ?bar/
          ).and matching(
            /[+>] ?baz/
          )).to_stdout
        end
      end
    end

    context 'using a local bucket' do
      let(:filea) {
        f = tmpfile('filea')
        File.binwrite(f, 'foo')
        f
      }
      let(:fileb) {
        f = tmpfile('fileb')
        File.binwrite(f, "bar\nbaz")
        f
      }
      let(:checksuma) { Digest::SHA256.file(filea).to_s }
      let(:checksumb) { Digest::SHA256.file(fileb).to_s }

      it 'compares to files stored in a local bucket' do
        expect {
          filebucket.command_line.args = ['backup', filea, '--local']
          filebucket.run
        }.to output(/#{filea}: #{checksuma}/).to_stdout

        expect{
          filebucket.command_line.args = ['backup', fileb, '--local']
          filebucket.run
        }.to output(/#{fileb}: #{checksumb}\n/).to_stdout

        expect {
          filebucket.command_line.args = ['diff', checksuma, checksumb, '--local']
          filebucket.run
        }.to output(a_string_matching(
          /[-<] ?foo/
        ).and matching(
          /[+>] ?bar/
        ).and matching(
          /[+>] ?baz/
        )).to_stdout
      end

      it 'compares a file on the filesystem and a file stored in a local bucket' do
        expect {
          filebucket.command_line.args = ['backup', filea, '--local']
          filebucket.run
        }.to output(/#{filea}: #{checksuma}/).to_stdout

        expect {
          filebucket.command_line.args = ['diff', checksuma, fileb, '--local']
          filebucket.run
        }.to output(a_string_matching(
          /[-<] ?foo/
        ).and matching(
          /[+>] ?bar/
        ).and matching(
          /[+>] ?baz/
        )).to_stdout
      end
    end
  end
end
