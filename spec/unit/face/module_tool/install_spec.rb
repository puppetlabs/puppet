require 'spec_helper'
require 'puppet/face'

describe "puppet module_tool install" do
  subject { Puppet::Face[:module_tool, :current] }

  let(:options) do
    {}
  end

  describe "option validation" do
    let(:expected_options) do
      {
        :install_dir => "/dev/null/modules",
        :module_repository => "http://forge.puppetlabs.com",
      }
    end

    context "without any options" do
      it "should require a name" do
        pattern = /wrong number of arguments/
        expect { subject.install }.to raise_error ArgumentError, pattern
      end

      it "should not require any options" do
        Puppet::Module::Tool::Applications::Installer.expects(:run).with("puppetlabs-apache", expected_options).once
        subject.install("puppetlabs-apache")
      end
    end

    it "should accept the --force option" do
      options[:force] = true
      expected_options.merge!(options)
      Puppet::Module::Tool::Applications::Installer.expects(:run).with("puppetlabs-apache", expected_options).once
      subject.install("puppetlabs-apache", options)
    end

    it "should accept the --install-dir option" do
      options[:install_dir] = "/foo/puppet/modules"
      expected_options.merge!(options)
      Puppet::Module::Tool::Applications::Installer.expects(:run).with("puppetlabs-apache", expected_options).once
      subject.install("puppetlabs-apache", options)
    end

    it "should accept the --module-repository option" do
      options[:module_repository] = "http://forge.example.com"
      expected_options.merge!(options)
      Puppet::Module::Tool::Applications::Installer.expects(:run).with("puppetlabs-apache", expected_options).once
      subject.install("puppetlabs-apache", options)
    end

    it "should accept the --version option" do
      options[:version] = "0.0.1"
      expected_options.merge!(options)
      Puppet::Module::Tool::Applications::Installer.expects(:run).with("puppetlabs-apache", expected_options).once
      subject.install("puppetlabs-apache", options)
    end
  end

  describe "inline documentation" do
    subject { Puppet::Face[:module_tool, :current].get_action :install }

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
