require 'spec_helper'
require 'puppet/face'
require 'puppet/module_tool'

describe "puppet module install" do
  include PuppetSpec::Files

  subject { Puppet::Face[:module, :current] }

  describe "option validation" do
    let(:sep) { File::PATH_SEPARATOR }
    let(:fakefirstpath)  { make_absolute("/my/fake/modpath") }
    let(:fakesecondpath) { make_absolute("/other/fake/path") }
    let(:fakemodpath)    { "#{fakefirstpath}#{sep}#{fakesecondpath}" }
    let(:fakedirpath)    { make_absolute("/my/fake/path") }
    let(:options) { {} }
    let(:environment) do
      Puppet::Node::Environment.create(:env, [fakefirstpath, fakesecondpath])
    end
    let(:expected_options) do
      {
        :target_dir  => fakefirstpath,
        :environment_instance => environment,
      }
    end

    around(:each) do |example|
      Puppet.override(:current_environment => environment) do
        example.run
      end
    end

    context "without any options" do
      it "requires a name" do
        pattern = /wrong number of arguments/
        expect { subject.install }.to raise_error ArgumentError, pattern
      end

      it "does not require any options" do
        expects_installer_run_with("puppetlabs-apache", expected_options)

        subject.install("puppetlabs-apache")
      end
    end

    it "accepts the --force option" do
      options[:force] = true
      expected_options.merge!(options)

      expects_installer_run_with("puppetlabs-apache", expected_options)

      subject.install("puppetlabs-apache", options)
    end

    it "accepts the --target-dir option" do
      options[:target_dir] = make_absolute("/foo/puppet/modules")
      expected_options.merge!(options)
      expected_options[:environment_instance] = environment.override_with(:modulepath => [options[:target_dir], fakefirstpath, fakesecondpath])

      expects_installer_run_with("puppetlabs-apache", expected_options)

      subject.install("puppetlabs-apache", options)
    end

    it "accepts the --version option" do
      options[:version] = "0.0.1"
      expected_options.merge!(options)

      expects_installer_run_with("puppetlabs-apache", expected_options)

      subject.install("puppetlabs-apache", options)
    end

    it "accepts the --ignore-dependencies option" do
      options[:ignore_dependencies] = true
      expected_options.merge!(options)

      expects_installer_run_with("puppetlabs-apache", expected_options)

      subject.install("puppetlabs-apache", options)
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

  def expects_installer_run_with(name, options)
    installer = mock("Installer")
    install_dir = mock("InstallDir")
    forge = mock("Forge")

    Puppet::Forge.expects(:new).with("PMT", subject.version).returns(forge)
    Puppet::ModuleTool::InstallDirectory.expects(:new).
      with(Pathname.new(expected_options[:target_dir])).
      returns(install_dir)
    Puppet::ModuleTool::Applications::Installer.expects(:new).
      with("puppetlabs-apache", forge, install_dir, expected_options).
      returns(installer)
    installer.expects(:run)
  end
end
