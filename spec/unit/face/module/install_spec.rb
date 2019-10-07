require 'spec_helper'
require 'puppet/face'
require 'puppet/module_tool'

describe "puppet module install" do
  include PuppetSpec::Files

  describe "action" do
    let(:name)        { double(:name) }
    let(:target_dir)  { tmpdir('module install face action') }
    let(:options)     { { :target_dir => target_dir } }

    it 'should invoke the Installer app' do
      expect(Puppet::ModuleTool).to receive(:set_option_defaults).with(options)
      expect(Puppet::ModuleTool::Applications::Installer).to receive(:run) do |mod, target, opts|
        expect(mod).to eql(name)
        expect(opts).to eql(options)
        expect(target).to be_a(Puppet::ModuleTool::InstallDirectory)
        expect(target.target).to eql(Pathname.new(target_dir))
      end

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
