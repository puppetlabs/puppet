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
        Puppet::Module::Tool::Applications::UnInstaller.expects(:run).once
        subject.uninstall("puppetlabs-apache")
      end
    end

    it "should accept the --target-directory option" do
      options[:target_directory] = "/foo/puppet/modules"
      expected_options = { :target_directories => ["/foo/puppet/modules"] }
      Puppet::Module::Tool::Applications::UnInstaller.expects(:run).with("puppetlabs-apache", expected_options).once
      subject.uninstall("puppetlabs-apache", options)
    end
  end

  describe "inline documentation" do
    subject { Puppet::Face[:module, :current].get_action :uninstall }

    its(:summary)     { should =~ /uninstall.*module/im }
    its(:description) { should =~ /uninstall.*module/im }
    its(:returns)     { should =~ /array of strings/i }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
