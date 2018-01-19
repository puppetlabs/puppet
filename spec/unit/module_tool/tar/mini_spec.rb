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
    writer = stub('GzipWriter')

    Zlib::GzipWriter.expects(:open).with(destfile).yields(writer)
    stats = {:mode => 0222}
    Archive::Tar::Minitar.expects(:pack).with(sourcedir, writer).yields(:file_start, 'abc', stats)

    minitar.pack(sourcedir, destfile)
  end

  it "packs a tar file on Windows" do
    writer = stub('GzipWriter')

    Zlib::GzipWriter.expects(:open).with(destfile).yields(writer)
    Archive::Tar::Minitar.expects(:pack).with(sourcedir, writer).
        yields(:file_start, 'abc', {:entry => MockFileStatEntry.new(nil)})

    minitar.pack(sourcedir, destfile)
  end

  def unpacks_the_entry(type, name, mode = 0100)
    reader = stub('GzipReader')

    Zlib::GzipReader.expects(:open).with(sourcefile).yields(reader)
    minitar.expects(:find_valid_files).with(reader).returns([name])
    entry = MockFileStatEntry.new(mode)
    Archive::Tar::Minitar.expects(:unpack).with(reader, destdir, [name]).
        yields(type, name, {:entry => entry})
    entry
  end
end
