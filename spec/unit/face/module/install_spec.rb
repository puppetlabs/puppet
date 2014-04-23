require 'spec_helper'
require 'puppet/face'
require 'puppet/module_tool'

describe "puppet module install" do
  include PuppetSpec::Files

  describe "action" do
    let(:name)        { stub(:name) }
    let(:target_dir)  { stub(:target_dir) }
    let(:target_path) { stub(:target_path) }
    let(:install_dir) { stub(:install_dir) }
    let(:options)     { { :target_dir => target_dir } }

    it 'should invoke the Installer app' do
      args = [ name, install_dir, options ]

      Puppet::ModuleTool.expects(:set_option_defaults).with(options)

      Pathname.expects(:new).with(target_dir).returns(target_path)
      Puppet::ModuleTool::InstallDirectory.expects(:new).with(target_path).returns(install_dir)
      Puppet::ModuleTool::Applications::Installer.expects(:run).with(*args)

      Puppet::Face[:module, :current].install(name, options)
    end
  end

  describe "inline documentation" do
    subject { Puppet::Face.find_action(:module, :install) }

    its(:summary)     { should =~ /install.*module/im }
    its(:description) { should =~ /install.*module/im }
    its(:returns)     { should =~ /pathname/i }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
