require 'spec_helper'
require 'puppet/face'
require 'puppet/module_tool'

describe "puppet module uninstall" do
  subject { Puppet::Face[:module, :current] }

  let(:options) do
    {}
  end

  describe "option validation" do
    context "without any options" do
      it "should require a name" do
        pattern = /wrong number of arguments/
        expect { subject.uninstall }.to raise_error ArgumentError, pattern
      end

      it "should not require any options" do
        Puppet::Module::Tool::Applications::Uninstaller.expects(:run).once
        subject.uninstall("puppetlabs-apache")
      end
    end

    it "should accept the --environment option" do
      options[:environment] = "development"
      expected_options = {
        :environment => 'development',
        :name => 'puppetlabs-apache'
      }
      Puppet::Module::Tool::Applications::Uninstaller.expects(:run).with("puppetlabs-apache", expected_options).once
      subject.uninstall("puppetlabs-apache", options)
    end

    it "should accept the --modulepath option" do
      options[:modulepath] = "/foo/puppet/modules"
      expected_options = {
        :modulepath => '/foo/puppet/modules',
        :environment => 'production',
        :name => 'puppetlabs-apache',
      }
      File.expects(:directory?).with("/foo/puppet/modules").returns(true)
      Puppet::Module::Tool::Applications::Uninstaller.expects(:run).with("puppetlabs-apache", expected_options).once
      subject.uninstall("puppetlabs-apache", options)
    end

    it "should accept the --version option" do
      options[:version] = "1.0.0"
      expected_options = {
        :version => '1.0.0',
        :environment => 'production',
        :name => 'puppetlabs-apache',
      }
      Puppet::Module::Tool::Applications::Uninstaller.expects(:run).with("puppetlabs-apache", expected_options).once
      subject.uninstall("puppetlabs-apache", options)
    end

    it "should accept the --force flag" do
      options[:force] = true
      expected_options = {
        :environment => 'production',
        :name => 'puppetlabs-apache',
        :force => true
      }
      Puppet::Module::Tool::Applications::Uninstaller.expects(:run).with("puppetlabs-apache", expected_options).once
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
