require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/modules'
require 'semver'

describe Puppet::ModuleTool::Applications::Checksummer, :fails_on_windows => true do
  subject { Puppet::ModuleTool::Applications::Checksummer.new(module_install_path) }

  let(:module_install_path) { 'foo' }
  let(:module_metadata_file) { 'metadata.json' }

  before(:all) do
    Pathname.class_eval do
      class << self
        alias_method :real_new, :new
      end
    end
  end

  after(:all) do
    Pathname.class_eval do
      class << self
        remove_method :real_new
      end
    end
  end

  def stub_module_pathname(relative_path, content, count = 1)
    Pathname.expects(:new).with(relative_path).returns(Pathname.real_new(relative_path)).times(count)
    path = "#{module_install_path}/#{relative_path}"
    pathname = Pathname.real_new(path)
    if content.nil?
      pathname.expects(:exist?).returns(false)
    else
      pathname.expects(:exist?).returns(true)
      pathname.expects(:read).returns(content)
    end
    Pathname.expects(:new).with(path).returns(pathname).times(count)
  end

  context %q{when metadata.json doesn't exist in the specified path} do
    it 'throws an exception' do
      module_install_pathname = Pathname.real_new(module_install_path)
      Pathname.expects(:new).with(module_install_path).returns(module_install_pathname)
      stub_module_pathname(module_metadata_file, nil)

      lambda { subject.run }.should raise_error(ArgumentError, 'No metadata.json found.')
    end
  end

  context 'when metadata.json exists in the specified path' do
    let(:module_files) {
      {
        'README' => 'Not much of a readme.'
      }
    }
    let(:module_metadata) {
      {
        'checksums' => {}.tap { |checksums|
          module_files.each { |file, content| checksums[file] = Digest::MD5.hexdigest(content) }
        }
      }
    }

    before(:each) do
      module_install_pathname = Pathname.real_new(module_install_path)
      Pathname.expects(:new).with(module_install_path).returns(module_install_pathname)
      Pathname.expects(:new).with(module_install_pathname).returns(Pathname.real_new(module_install_pathname))
      stub_module_pathname(module_metadata_file, PSON.dump(module_metadata), 2)
    end

    it 'reports removed files' do
      removed_file = module_files.keys[0]

      stub_module_pathname(removed_file, nil)

      subject.run.should == [removed_file]
    end

    it 'reports changed files' do
      changed_file = module_files.keys[0]

      stub_module_pathname(changed_file, ' ' << module_files[changed_file])

      subject.run.should == [changed_file]
    end

    it 'does not report unchanged files' do
      unchanged_file = module_files.keys[0]

      stub_module_pathname(unchanged_file, module_files[unchanged_file])

      subject.run.should == []
    end
  end
end
