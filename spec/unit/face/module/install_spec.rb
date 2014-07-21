require 'spec_helper'
require 'puppet/face'
require 'puppet/module_tool'

describe "puppet module install" do
  include PuppetSpec::Files

  describe "action" do
    let(:name)        { "ownername/modulenname" }
    let(:target_dir)  { make_absolute("/my/target/dir") }
    let(:target_path) { make_absolute("/my/target/path") }
    let(:install_dir) { make_absolute("/my/install_dir") }
    let(:options)     { { :target_dir => target_dir } }

    it 'should invoke the Installer app' do
      Puppet::ModuleTool.expects(:set_option_defaults).with(options)

      Puppet::ModuleTool::Applications::Installer.expects(:run).with do |*args|
        expect(args[0]).to eq(name)
        expect(args[1]).to be_a_kind_of Puppet::ModuleTool::InstallDirectory
        expect(args[1].target).to eq(Pathname.new(target_dir))
        expect(args[2]).to eq(options)
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
