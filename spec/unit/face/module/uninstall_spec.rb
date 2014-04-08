require 'spec_helper'
require 'puppet/face'
require 'puppet/module_tool'

describe "puppet module uninstall" do
  include PuppetSpec::Files

  describe "action" do
    let(:name)    { 'module-name' }
    let(:options) { Hash.new }

    it 'should invoke the Uninstaller app' do
      args = [ name, options ]

      Puppet::ModuleTool.expects(:set_option_defaults).with(options)
      Puppet::ModuleTool::Applications::Uninstaller.expects(:run).with(*args)

      Puppet::Face[:module, :current].uninstall(name, options)
    end

    context 'slash-separated module name' do
      let(:name) { 'module/name' }

      it 'should invoke the Uninstaller app' do
        args = [ 'module-name', options ]

        Puppet::ModuleTool.expects(:set_option_defaults).with(options)
        Puppet::ModuleTool::Applications::Uninstaller.expects(:run).with(*args)

        Puppet::Face[:module, :current].uninstall(name, options)
      end
    end
  end

  describe "inline documentation" do
    subject { Puppet::Face.find_action(:module, :uninstall) }

    its(:summary)     { should =~ /uninstall.*module/im }
    its(:description) { should =~ /uninstall.*module/im }
    its(:returns)     { should =~ /uninstalled modules/i }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
