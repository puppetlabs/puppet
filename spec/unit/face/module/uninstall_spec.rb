require 'spec_helper'
require 'puppet/face'
require 'puppet/module_tool'

describe "puppet module uninstall" do
  subject { Puppet::Face[:module, :current] }

  let(:options) do
    {}
  end
  let(:modulepath) { File.expand_path('/module/path') }
  let(:environment) do
    Puppet::Node::Environment.create(:env, [modulepath])
  end
  let(:expected_options) do
    {
      :target_dir  => modulepath,
      :environment_instance => environment,
    }
  end

  describe "option validation" do
    around(:each) do |example|
      Puppet.override(:current_environment => environment) do
        example.run
      end
    end

    context "without any options" do
      it "should require a name" do
        pattern = /wrong number of arguments/
        expect { subject.uninstall }.to raise_error ArgumentError, pattern
      end

      it "should not require any options" do
        Puppet::ModuleTool::Applications::Uninstaller.expects(:run).once
        subject.uninstall("puppetlabs-apache")
      end
    end

    it "should accept the --version option" do
      options[:version] = "1.0.0"
      expected_options.merge!(:version => '1.0.0')
      Puppet::ModuleTool::Applications::Uninstaller.expects(:run).with("puppetlabs-apache", has_entries(expected_options)).once
      subject.uninstall("puppetlabs-apache", options)
    end

    it "should accept the --force flag" do
      options[:force] = true
      expected_options.merge!(:force => true)
      Puppet::ModuleTool::Applications::Uninstaller.expects(:run).with("puppetlabs-apache", has_entries(expected_options)).once
      subject.uninstall("puppetlabs-apache", options)
    end
  end

  describe "inline documentation" do
    subject { Puppet::Face[:module, :current].get_action :uninstall }

    its(:summary)     { should =~ /uninstall.*module/im }
    its(:description) { should =~ /uninstall.*module/im }
    its(:returns)     { should =~ /hash of module objects.*/im }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
