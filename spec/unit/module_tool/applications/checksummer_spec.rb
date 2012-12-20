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

  context %q{when metadata.json doesn't exist in the specified module installation path} do
    before(:each) do
      stub_module_file_pathname(module_metadata_file, false)
      subject.expects(:metadata_file).with().\
        returns(module_install_pathname + module_metadata_file)
    end

    it 'raises an ArgumentError exception' do
      lambda {
        subject.run
      }.should raise_error(ArgumentError, 'No metadata.json found.')
    end
  end

  context 'when metadata.json exists in the specified module installation path' do
    module_files = {
      'README'     => '1',
      'CHANGELOG'  => '2',
      'Modulefile' => '3',
    }
    let(:module_files) { module_files }
    let(:checksum_computer) {
      checksums = mock()
      Puppet::ModuleTool::Checksums.\
        expects(:new).with(module_install_pathname).\
        returns(checksums)
      checksums
    }
    # all possible combinations (of all lengths) of the module files
    module_files_combination =
      1.upto(module_files.size()).inject([]) { |module_files_combination, n|
        module_files.keys.combination(n) { |combination|
          module_files_combination << combination
        }
        module_files_combination
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
      overrides.reject! { |key, value|
        !module_files.include?(key)
      }
      module_files.merge(overrides).each { |relative_path, checksum|
        stub_module_file_pathname_with_checksum(relative_path, checksum)
      }
    end

    before(:each) do
      stub_module_file_pathname(module_metadata_file, true)
      subject.expects(:metadata_file).with().\
        returns(module_install_pathname + module_metadata_file)
      subject.expects(:metadata).with().\
        returns({ 'checksums' => module_files })
    end

    module_files_combination.each do |removed_files|
      it "reports removed file(s) #{removed_files.inspect}" do
        stub_module_files(
          removed_files.inject({}) { |overrides, removed_file|
            overrides[removed_file] = nil
            overrides
          }
        )

        subject.run.should == removed_files
      end
    end

    module_files_combination.each do |changed_files|
      it "reports changed file(s) #{changed_files.inspect}" do
        stub_module_files(
          changed_files.inject({}) { |overrides, changed_file|
            changed_checksum = module_files[changed_file].to_s.succ
            changed_checksum = ' ' if changed_checksum.empty?
            overrides[changed_file] = changed_checksum
            overrides
          }
        )

        subject.run.should == changed_files
      end
    end

    it 'does not report unchanged files' do
      stub_module_files()

      subject.run.should == []
    end
  end
end
