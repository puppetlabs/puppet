require 'spec_helper'
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
    end

    it "overwrites existing checksums.json" do
      origchecksumjson = {'metadata.json' => '0123456789abcdef',
          'Modulefile' => '0123456789abcdef',
        }.to_json

      File.open(File.join(path, 'checksums.json'), 'w') do |f|
        f.puts(origchecksumjson)
      end
      tarrer = mock('tarrer')
      Puppet::ModuleTool::Tar.expects(:instance).returns(tarrer)
      Dir.expects(:chdir).with(File.join(path, 'pkg')).yields
      tarrer.expects(:pack).with(release_name, tarball)

      builder.run

      buildchecksums = File.read(File.join(path, "pkg/#{release_name}/checksums.json"))
      buildchecksums.should_not == origchecksumjson
    end

    it "removes existing checksums field from metadata.json" do
      tarrer = mock('tarrer')
      Puppet::ModuleTool::Tar.expects(:instance).returns(tarrer)
      Dir.expects(:chdir).with(File.join(path, 'pkg')).yields
      tarrer.expects(:pack).with(release_name, tarball)

      builder.run

      metadatajson = File.read(File.join(path, "pkg/#{release_name}/metadata.json"))
      JSON.parse(metadatajson).should_not include('checksums')
      JSON.parse(metadatajson).should include('name')
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
          "checksums" => {"module/init.pp" => "0123456789abcdef"}
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
