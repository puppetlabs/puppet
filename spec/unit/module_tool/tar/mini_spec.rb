require 'spec_helper'
require 'puppet/module_tool'

describe Puppet::ModuleTool::Tar::Mini, :if => (Puppet.features.minitar? and Puppet.features.zlib?) do
  let(:sourcefile) { '/the/module.tar.gz' }
  let(:destdir)    { File.expand_path '/the/dest/dir' }
  let(:sourcedir)  { '/the/src/dir' }
  let(:destfile)   { '/the/dest/file.tar.gz' }
  let(:minitar)    { described_class.new }

  class MockFileStatEntry
    def initialize(mode = 0100)
      @mode = mode
    end
  end

  it "unpacks a tar file with correct permissions" do
    entry = unpacks_the_entry(:file_start, 'thefile')

    minitar.unpack(sourcefile, destdir, 'uid')
    expect(entry.instance_variable_get(:@mode)).to eq(0755)
  end

  it "does not allow an absolute path" do
    unpacks_the_entry(:file_start, '/thefile')

    expect {
      minitar.unpack(sourcefile, destdir, 'uid')
    }.to raise_error(Puppet::ModuleTool::Errors::InvalidPathInPackageError,
                     "Attempt to install file with an invalid path into \"/thefile\" under \"#{destdir}\"")
  end

  it "does not allow a file to be written outside the destination directory" do
    unpacks_the_entry(:file_start, '../../thefile')

    expect {
      minitar.unpack(sourcefile, destdir, 'uid')
    }.to raise_error(Puppet::ModuleTool::Errors::InvalidPathInPackageError,
                     "Attempt to install file with an invalid path into \"#{File.expand_path('/the/thefile')}\" under \"#{destdir}\"")
  end

  it "does not allow a directory to be written outside the destination directory" do
    unpacks_the_entry(:dir, '../../thedir')

    expect {
      minitar.unpack(sourcefile, destdir, 'uid')
    }.to raise_error(Puppet::ModuleTool::Errors::InvalidPathInPackageError,
                     "Attempt to install file with an invalid path into \"#{File.expand_path('/the/thedir')}\" under \"#{destdir}\"")
  end

  it "unpacks on Windows" do
    unpacks_the_entry(:file_start, 'thefile', nil)

    entry = minitar.unpack(sourcefile, destdir, 'uid')
    # Windows does not use these permissions.
    expect(entry.instance_variable_get(:@mode)).to eq(nil)
  end

  it "packs a tar file" do
    writer = double('GzipWriter')

    expect(Zlib::GzipWriter).to receive(:open).with(destfile).and_yield(writer)
    stats = {:mode => 0222}
    expect(Minitar).to receive(:pack).with(sourcedir, writer).and_yield(:file_start, 'abc', stats)

    minitar.pack(sourcedir, destfile)
  end

  it "packs a tar file on Windows" do
    writer = double('GzipWriter')

    expect(Zlib::GzipWriter).to receive(:open).with(destfile).and_yield(writer)
    expect(Minitar).to receive(:pack).with(sourcedir, writer).
        and_yield(:file_start, 'abc', {:entry => MockFileStatEntry.new(nil)})

    minitar.pack(sourcedir, destfile)
  end

  def unpacks_the_entry(type, name, mode = 0100)
    reader = double('GzipReader')

    expect(Zlib::GzipReader).to receive(:open).with(sourcefile).and_yield(reader)
    expect(minitar).to receive(:find_valid_files).with(reader).and_return([name])
    entry = MockFileStatEntry.new(mode)
    expect(Minitar).to receive(:unpack).with(reader, destdir, [name], {:fsync => false}).
        and_yield(type, name, {:entry => entry})
    entry
  end

  describe "Extracts tars with long and short pathnames" do
    let (:sourcetar) { fixtures('module.tar.gz') }
    let (:longfilepath)  { "puppetlabs-dsc-1.0.0/lib/puppet_x/dsc_resources/xWebAdministration/DSCResources/MSFT_xWebAppPoolDefaults/MSFT_xWebAppPoolDefaults.schema.mof" }
    let (:shortfilepath) { "puppetlabs-dsc-1.0.0/README.md" }

    it "unpacks a tar with a short path length" do
      extractdir = PuppetSpec::Files.tmpdir('minitar')

      minitar.unpack(sourcetar,extractdir,'module')
      expect(File).to exist(File.expand_path("#{extractdir}/#{shortfilepath}"))
    end

    it "unpacks a tar with a long path length" do
      extractdir = PuppetSpec::Files.tmpdir('minitar')

      minitar.unpack(sourcetar,extractdir,'module')
      expect(File).to exist(File.expand_path("#{extractdir}/#{longfilepath}"))
    end
  end
end
