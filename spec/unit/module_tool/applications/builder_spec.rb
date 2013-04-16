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
  let(:builder)      { Puppet::ModuleTool::Applications::Builder.new(path) }

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
  end

  it "should attempt to create a module relative to the pkg directory" do
    tarrer = mock('tarrer')
    Puppet::ModuleTool::Tar.expects(:instance).with(module_name).returns(tarrer)
    Dir.expects(:chdir).with(File.join(path, 'pkg')).yields
    tarrer.expects(:pack).with(release_name, tarball)

    builder.run
  end
end
