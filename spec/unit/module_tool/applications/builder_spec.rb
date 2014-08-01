require 'spec_helper'
require 'puppet/file_system'
require 'puppet/module_tool/applications'
require 'puppet_spec/modules'

describe Puppet::ModuleTool::Applications::Builder do
  include PuppetSpec::Files

  let(:path)         { tmpdir("working_dir") }
  let(:module_name)  { 'mymodule-mytarball' }
  let(:version)      { '0.0.1' }
  let(:release_name) { "#{module_name}-#{version}" }
  let(:tarball)      { File.join(path, 'pkg', release_name) + ".tar.gz" }
  let(:builder)      { Puppet::ModuleTool::Applications::Builder.new(path) }

  shared_examples "a packagable module" do
    def target_exists?(file)
      File.exist?(File.join(path, "pkg", "#{module_name}-#{version}", file))
    end

    it "packages the module in a tarball named after the module" do
      tarrer = mock('tarrer')
      Puppet::ModuleTool::Tar.expects(:instance).returns(tarrer)
      Dir.expects(:chdir).with(File.join(path, 'pkg')).yields
      tarrer.expects(:pack).with(release_name, tarball)

      builder.run

      expect(target_exists?('checksums.json')).to be true
      expect(target_exists?('metadata.json')).to be true
    end
  end

  context 'with metadata.json' do
    before :each do
      File.open(File.join(path, 'metadata.json'), 'w') do |f|
        f.puts({
          "name" => "#{module_name}",
          "version" => "#{version}",
          "source" => "http://github.com/testing/#{module_name}",
          "author" => "testing",
          "license" => "Apache License Version 2.0",
          "summary" => "Puppet testing module",
          "description" => "This module can be used for basic testing",
          "project_page" => "http://github.com/testing/#{module_name}"
        }.to_json)
      end
    end

    it_behaves_like "a packagable module"

    it "does not package with a symlink", :if => Puppet.features.manages_symlinks? do
      FileUtils.touch(File.join(path, 'tempfile'))
      Puppet::FileSystem.symlink(File.join(path, 'tempfile'), File.join(path, 'tempfile2'))

      expect {
        builder.run
      }.to raise_error Puppet::ModuleTool::Errors::ModuleToolError, /symlinks/i
    end

    it "does not package with a symlink in a subdir", :if => Puppet.features.manages_symlinks? do
      FileUtils.mkdir(File.join(path, 'manifests'))
      FileUtils.touch(File.join(path, 'manifests/tempfile.pp'))
      Puppet::FileSystem.symlink(File.join(path, 'manifests/tempfile.pp'), File.join(path, 'manifests/tempfile2.pp'))

      expect {
        builder.run
      }.to raise_error Puppet::ModuleTool::Errors::ModuleToolError, /symlinks/i
    end
  end

  context 'with metadata.json containing checksums' do
    before :each do
      File.open(File.join(path, 'metadata.json'), 'w') do |f|
        f.puts({
          "name" => "#{module_name}",
          "version" => "#{version}",
          "source" => "http://github.com/testing/#{module_name}",
          "author" => "testing",
          "license" => "Apache License Version 2.0",
          "summary" => "Puppet testing module",
          "description" => "This module can be used for basic testing",
          "project_page" => "http://github.com/testing/#{module_name}",
          "checksums" => {"README.md" => "deadbeef"}
        }.to_json)
      end
    end

    it_behaves_like "a packagable module"
  end

  context 'with Modulefile' do
    before :each do
      File.open(File.join(path, 'Modulefile'), 'w') do |f|
        f.write <<-MODULEFILE
name    '#{module_name}'
version '#{version}'
source 'http://github.com/testing/#{module_name}'
author 'testing'
license 'Apache License Version 2.0'
summary 'Puppet testing module'
description 'This module can be used for basic testing'
project_page 'http://github.com/testing/#{module_name}'
MODULEFILE
      end
    end

    it_behaves_like "a packagable module"
  end
end
