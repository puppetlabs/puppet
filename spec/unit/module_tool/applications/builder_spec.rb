require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/modules'

describe Puppet::ModuleTool::Applications::Builder do
  include PuppetSpec::Files

  let(:path)         { tmpdir("working_dir") }
  let(:module_name)  { 'myusername-mytarball' }
  let(:version)      { '0.0.1' }
  let(:release_name) { "#{module_name}-#{version}" }
  let(:tarball)      { File.join(path, 'pkg', release_name) + ".tar.gz" }
  let(:options)      { {} }
  let(:builder)      { Puppet::ModuleTool::Applications::Builder.new(path, options) }

  before :each do
    File.open(File.join(path, 'Modulefile'), 'w') do |f|
      f.write(<<EOM)
name    '#{module_name}'
version '#{version}'
source 'http://github.com/testing/#{module_name}'
author 'testing'
license 'Apache License Version 2.0'
summary 'Puppet testing module'
description 'This module can be used for basic testing'
project_page 'http://github.com/testing/#{module_name}'
EOM
    end
    ['coverage','pkg',['spec','fixtures','manifests'],['spec','fixtures','modules']].each do |f|
      FileUtils.mkdir_p(File.join(path, *f))
    end
  end

  before do
    tarrer = mock('tarrer')
    Puppet::ModuleTool::Tar.expects(:instance).returns(tarrer)
    Dir.expects(:chdir).with(File.join(path, 'pkg')).yields
    tarrer.expects(:pack).with(release_name, tarball)
    builder.run
  end

  def target_exists?(*file)
    File.exist?(File.join(path, "pkg", "#{module_name}-#{version}", file))
  end

  shared_examples :build do
    it "should create metadata.json" do
      target_exists?("metadata.json").should be_true
    end
    it "should not create default excluded files" do
      target_exists?("coverage").should be_false
      target_exists?("pkg").should be_false
    end
  end

  context "when using default parameters" do
    it_behaves_like :build
    it "should include fixtures/manifests dir" do
      target_exists?("spec", "fixtures", "manifests").should be_true
    end
    it "should include fixtures/modules dir" do
      target_exists?("spec", "fixtures", "modules").should be_true
    end
  end

  context "when using exclusions" do
    let(:options) { { :exclude => "spec/fixtures/manifests,modul.*" }}
    it_behaves_like :build
    it "should not include fixtures/manifests dir" do
      target_exists?("spec", "fixtures", "manifests").should be_false
    end
    it "should not include fixtures/modules dir" do
      target_exists?("spec", "fixtures", "modules").should be_false
    end
  end

end
