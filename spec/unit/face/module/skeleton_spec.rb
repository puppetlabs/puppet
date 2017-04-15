# encoding: UTF-8

require 'spec_helper'
require 'puppet/face'
require 'puppet/module_tool'
require 'puppet_spec/modules'

describe "puppet module skeleton" do
  include PuppetSpec::Files

  before do
    dir = tmpdir("deep_path")

    @skelepath1 = File.join(dir, "skelepath1")
    @skelpath = "#{@skelepath1}"
    @pathname_stub = Pathname(__FILE__).dirname.to_s.gsub(/spec\/unit\/face\/module/,'lib/puppet/module_tool/') + 'skeleton/templates/generator'
    Puppet.settings[:module_skeleton_dir] = @skelpath

    FileUtils.mkdir_p(@skelepath1)
  end

  around do |example|
    Puppet.override(:environments => Puppet::Environments::Legacy.new()) do
      example.run
    end
  end

  it "should return a list of skeleton files" do
    Puppet::Face[:module, :current].skeleton["Default Path"].should eql Pathname(@pathname_stub)
    Puppet::Face[:module, :current].skeleton["Custom Path"].should eql Pathname(@skelepath1)
  end
end
