require 'spec_helper'
require 'puppet/face'
require 'puppet/module_tool'

describe "puppet module build" do
  subject { Puppet::Face[:module, :current] }

  describe "when called without any options" do
    it "if current directory is a module root should call builder with it" do
      Dir.expects(:pwd).returns('/a/b/c')
      Puppet::ModuleTool.expects(:find_module_root).with('/a/b/c').returns('/a/b/c')
      Puppet::ModuleTool.expects(:set_option_defaults).returns({})
      Puppet::ModuleTool::Applications::Builder.expects(:run).with('/a/b/c', {})
      subject.build
    end

    it "if parent directory of current dir is a module root should call builder with it" do
      Dir.expects(:pwd).returns('/a/b/c')
      Puppet::ModuleTool.expects(:find_module_root).with('/a/b/c').returns('/a/b')
      Puppet::ModuleTool.expects(:set_option_defaults).returns({})
      Puppet::ModuleTool::Applications::Builder.expects(:run).with('/a/b', {})
      subject.build
    end

    it "if current directory or parents contain no module root, should return exception" do
      Dir.expects(:pwd).returns('/a/b/c')
      Puppet::ModuleTool.expects(:find_module_root).returns(nil)
      expect { subject.build }.to raise_error RuntimeError, "Unable to find metadata.json in module root /a/b/c or parent directories. See <https://docs.puppetlabs.com/puppet/latest/reference/modules_publishing.html> for required file format."
    end
  end

  describe "when called with a path" do
    it "if path is a module root should call builder with it" do
      Puppet::ModuleTool.expects(:is_module_root?).with('/a/b/c').returns(true)
      Puppet::ModuleTool.expects(:set_option_defaults).returns({})
      Puppet::ModuleTool::Applications::Builder.expects(:run).with('/a/b/c', {})
      subject.build('/a/b/c')
    end

    it "if path is not a module root should raise exception" do
      Puppet::ModuleTool.expects(:is_module_root?).with('/a/b/c').returns(false)
      expect { subject.build('/a/b/c') }.to raise_error RuntimeError, "Unable to find metadata.json in module root /a/b/c or parent directories. See <https://docs.puppetlabs.com/puppet/latest/reference/modules_publishing.html> for required file format."
    end
  end

  describe "with options" do
    it "should pass through options to builder when provided" do
      Puppet::ModuleTool.stubs(:is_module_root?).returns(true)
      Puppet::ModuleTool.expects(:set_option_defaults).returns({})
      Puppet::ModuleTool::Applications::Builder.expects(:run).with('/a/b/c', {:modulepath => '/x/y/z'})
      subject.build('/a/b/c', :modulepath => '/x/y/z')
    end
  end

  describe "inline documentation" do
    subject { Puppet::Face[:module, :current].get_action :build }

    its(:summary)     { should =~ /build.*module/im }
    its(:description) { should =~ /build.*module/im }
    its(:returns)     { should =~ /pathname/i }
    its(:examples)    { should_not be_empty }

    %w{ license copyright summary description returns examples }.each do |doc|
      context "of the" do
        its(doc.to_sym) { should_not =~ /(FIXME|REVISIT|TODO)/ }
      end
    end
  end
end
