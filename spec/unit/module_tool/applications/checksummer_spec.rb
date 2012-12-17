require 'spec_helper'
require 'puppet/module_tool/applications'

describe Puppet::ModuleTool::Applications::Checksummer, :fails_on_windows => true do
  subject {
    Puppet::ModuleTool::Applications::Checksummer.new(module_install_path)
  }

  let(:module_install_path) { 'foo' }
  let(:module_metadata_file) { 'metadata.json' }

  let(:module_install_pathname) {
    module_install_pathname = mock()
    Pathname.expects(:new).with(module_install_path).\
      returns(module_install_pathname)
    module_install_pathname
  }

  def stub_module_file_pathname(relative_path, present)
    module_file_pathname = mock() do
      expects(:exist?).with().returns(present)
    end

    module_install_pathname.expects(:+).with(relative_path).\
      returns(module_file_pathname)

    module_file_pathname
  end

  context %q{when metadata.json doesn't exist in the specified path} do
    before(:each) do
      stub_module_file_pathname(module_metadata_file, false)
      subject.expects(:metadata_file).with().\
        returns(module_install_pathname + module_metadata_file)
    end

    it 'throws an exception' do
      lambda {
        subject.run
      }.should raise_error(ArgumentError, 'No metadata.json found.')
    end
  end

  context 'when metadata.json exists in the specified path' do
    let(:module_files) {
      {
        'README'     => '1',
        'CHANGELOG'  => '2',
        'Modulefile' => '3',
      }
    }
    let(:checksum_computer) {
      checksums = mock()
      Puppet::ModuleTool::Checksums.\
        expects(:new).with(module_install_pathname).\
        returns(checksums)
      checksums
    }

    def stub_module_file_pathname_with_checksum(relative_path, checksum)
      module_file_pathname = 
        stub_module_file_pathname(relative_path, present = !checksum.nil?)
      # mock the call of Puppet::ModuleTool::Checksums#checksum
      expectation = checksum_computer.\
        expects(:checksum).with(module_file_pathname)
      if present
        # return the cheksum directly
        expectation.returns(checksum)
      else
        # if the file is not present, then the method should not be called
        expectation.times(0)
      end
      module_file_pathname
    end

    def stub_module_files(overrides = {})
      module_files.merge(overrides).each do |relative_path, checksum|
        stub_module_file_pathname_with_checksum(relative_path, checksum)
      end
    end

    def get_random_module_file()
      module_files.keys[rand(module_files.size)]
    end

    before(:each) do
      stub_module_file_pathname(module_metadata_file, true)
      subject.expects(:metadata_file).with().\
        returns(module_install_pathname + module_metadata_file)
      subject.expects(:metadata).with().\
        returns({ 'checksums' => module_files })
    end

    it 'reports removed files' do
      removed_file = get_random_module_file()

      stub_module_files(removed_file => nil)

      subject.run.should == [removed_file]
    end

    it 'reports changed files' do
      changed_file = get_random_module_file()

      stub_module_files(changed_file => '1' << module_files[changed_file])

      subject.run.should == [changed_file]
    end

    it 'does not report unchanged files' do
      stub_module_files()

      subject.run.should == []
    end
  end
end
