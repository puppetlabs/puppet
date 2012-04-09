require 'spec_helper'
require 'puppet/face'
require 'puppet/module_tool'

describe "puppet module install" do

  subject { Puppet::Face[:module, :current] }

  let(:options) do
    {}
  end

  describe "option validation" do
    before do
      Puppet.settings[:modulepath] = fakemodpath
    end

    let(:expected_options) do
      {
        :target_dir  => fakefirstpath,
        :modulepath  => fakemodpath,
        :environment => 'production'
      }
    end

    let(:sep) { File::PATH_SEPARATOR }
    let(:fakefirstpath)  { "/my/fake/modpath" }
    let(:fakesecondpath) { "/other/fake/path" }
    let(:fakemodpath)    { "#{fakefirstpath}#{sep}#{fakesecondpath}" }
    let(:fakedirpath)    { "/my/fake/path" }

    context "without any options" do
      it "should require a name" do
        pattern = /wrong number of arguments/
        expect { subject.install }.to raise_error ArgumentError, pattern
      end

      it "should not require any options" do
        Puppet::ModuleTool::Applications::Installer.expects(:run).with("puppetlabs-apache", expected_options).once
        subject.install("puppetlabs-apache")
      end
    end

    it "should accept the --force option" do
      options[:force] = true
      expected_options.merge!(options)
      Puppet::ModuleTool::Applications::Installer.expects(:run).with("puppetlabs-apache", expected_options).once
      subject.install("puppetlabs-apache", options)
    end

    it "should accept the --target-dir option" do
      options[:target_dir] = "/foo/puppet/modules"
      expected_options.merge!(options)
      expected_options[:modulepath] = "#{options[:target_dir]}#{sep}#{fakemodpath}"

      Puppet::ModuleTool::Applications::Installer.expects(:run).with("puppetlabs-apache", expected_options).once
      subject.install("puppetlabs-apache", options)
    end

    it "should accept the --version option" do
      options[:version] = "0.0.1"
      expected_options.merge!(options)
      Puppet::ModuleTool::Applications::Installer.expects(:run).with("puppetlabs-apache", expected_options).once
      subject.install("puppetlabs-apache", options)
    end

    it "should accept the --ignore-dependencies option" do
      options[:ignore_dependencies] = true
      expected_options.merge!(options)
      Puppet::ModuleTool::Applications::Installer.expects(:run).with("puppetlabs-apache", expected_options).once
      subject.install("puppetlabs-apache", options)
    end

    describe "when modulepath option is passed" do
      let(:expected_options) { { :modulepath => fakemodpath, :environment => 'production' } }
      let(:options)          { { :modulepath => fakemodpath } }

      describe "when target-dir option is not passed" do
        it "should set target-dir to be first path from modulepath" do
          expected_options[:target_dir] = fakefirstpath

          Puppet::ModuleTool::Applications::Installer.
            expects(:run).
            with("puppetlabs-apache", expected_options)

          Puppet::Face[:module, :current].install("puppetlabs-apache", options)

          Puppet.settings[:modulepath].should == fakemodpath
        end
      end

      describe "when target-dir option is passed" do
        it "should set target-dir to be first path of modulepath" do
          options[:target_dir] = fakedirpath
          expected_options[:target_dir] = fakedirpath
          expected_options[:modulepath] = "#{fakedirpath}#{sep}#{fakemodpath}"

          Puppet::ModuleTool::Applications::Installer.
            expects(:run).
            with("puppetlabs-apache", expected_options)

          Puppet::Face[:module, :current].install("puppetlabs-apache", options)

          Puppet.settings[:modulepath].should == "#{fakedirpath}#{sep}#{fakemodpath}"
        end
      end
    end

    describe "when modulepath option is not passed" do
      before do
        Puppet.settings[:modulepath] = fakemodpath
      end

      describe "when target-dir option is not passed" do
        it "should set target-dir to be first path of default mod path" do
          expected_options[:target_dir] = fakefirstpath
          expected_options[:modulepath] = fakemodpath

          Puppet::ModuleTool::Applications::Installer.
            expects(:run).
            with("puppetlabs-apache", expected_options)

          Puppet::Face[:module, :current].install("puppetlabs-apache", options)
        end
      end

      describe "when target-dir option is passed" do
        it "should prepend target-dir to modulepath" do
          options[:target_dir] = fakedirpath
          expected_options[:target_dir] = fakedirpath
          expected_options[:modulepath] = "#{options[:target_dir]}#{sep}#{fakemodpath}"

          Puppet::ModuleTool::Applications::Installer.
            expects(:run).
            with("puppetlabs-apache", expected_options)

          Puppet::Face[:module, :current].install("puppetlabs-apache", options)
          Puppet.settings[:modulepath].should == expected_options[:modulepath]
        end
      end
    end
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
