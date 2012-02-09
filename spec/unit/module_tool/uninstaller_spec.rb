require 'spec_helper'
require 'puppet/module_tool'
require 'tmpdir'

describe Puppet::Module::Tool::Applications::Uninstaller do
  include PuppetSpec::Files

  describe "instances" do
    let(:tmp_module_path1) { tmpdir("uninstaller_module_path1") }
    let(:tmp_module_path2) { tmpdir("uninstaller_module_path2") }
    let(:options) do
      { :target_directories => [ tmp_module_path1, tmp_module_path2 ] }
    end

    it "should return an empty list if the module is not installed" do
      described_class.new('foo', options).run.should == []
    end

    it "should uninstall an installed module" do
      foo_module_path = File.join(tmp_module_path1, 'foo')
      Dir.mkdir(foo_module_path)
      described_class.new('foo', options).run.should == [ foo_module_path ]
    end

    it "should only uninstall the requested module" do
      foo_module_path = File.join(tmp_module_path1, 'foo')
      bar_module_path = File.join(tmp_module_path1, 'bar')
      Dir.mkdir(foo_module_path)
      Dir.mkdir(bar_module_path)
      described_class.new('foo', options).run.should == [ foo_module_path ]
    end

    it "should uninstall the module from all target directories" do
      foo1_module_path = File.join(tmp_module_path1, 'foo')
      foo2_module_path = File.join(tmp_module_path2, 'foo')
      Dir.mkdir(foo1_module_path)
      Dir.mkdir(foo2_module_path)
      described_class.new('foo', options).run.should == [ foo1_module_path, foo2_module_path ]
    end

    #11803
    it "should check for broken dependencies"
  end
end
