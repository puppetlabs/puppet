require 'spec_helper'
require 'puppet/face'
require 'puppet/module_tool'

describe "puppet module install" do
  subject { Puppet::Face[:module, :current] }

  let(:options) do
    {}
  end

  describe "option validation" do
    let(:expected_options) do
      {
        :dir => File.expand_path("/dev/null/modules"),
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

    it "should accept the --dir option" do
      options[:dir] = "/foo/puppet/modules"
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
    it "should set dir to be modulepath"
    it "should override dir as modulepath if modulepath specified"
  end

  describe "inline documentation" do
    subject { Puppet::Face[:module, :current].get_action :install }

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
