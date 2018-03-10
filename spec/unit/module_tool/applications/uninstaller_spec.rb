require 'spec_helper'
require 'puppet/module_tool'
require 'tmpdir'
require 'puppet_spec/module_tool/shared_functions'
require 'puppet_spec/module_tool/stub_source'

describe Puppet::ModuleTool::Applications::Uninstaller do
  include PuppetSpec::ModuleTool::SharedFunctions
  include PuppetSpec::Files

  before do
    FileUtils.mkdir_p(primary_dir)
    FileUtils.mkdir_p(secondary_dir)
  end

  let(:environment) do
    Puppet.lookup(:current_environment).override_with(
      :vardir     => vardir,
      :modulepath => [ primary_dir, secondary_dir ]
    )
  end

  let(:vardir)   { tmpdir('uninstaller') }
  let(:primary_dir) { File.join(vardir, "primary") }
  let(:secondary_dir) { File.join(vardir, "secondary") }
  let(:remote_source) { PuppetSpec::ModuleTool::StubSource.new }

  let(:module) { 'module-not_installed' }
  let(:application) do
    opts = options
    Puppet::ModuleTool.set_option_defaults(opts)
    Puppet::ModuleTool::Applications::Uninstaller.new(self.module, opts)
  end

  def options
    { :environment => environment }
  end

  subject { application.run }

  context "when the module is not installed" do
    it "should fail" do
      expect(subject).to include :result => :failure
    end
  end

  context "when the module is installed" do
    let(:module) { 'pmtacceptance-stdlib' }

    before { preinstall('pmtacceptance-stdlib', '1.0.0') }
    before { preinstall('pmtacceptance-apache', '0.0.4') }

    it "should uninstall the module" do
      expect(subject[:affected_modules].first.forge_name).to eq("pmtacceptance/stdlib")
    end

    it "should only uninstall the requested module" do
      subject[:affected_modules].length == 1
    end

    context 'in two modulepaths' do
      before { preinstall('pmtacceptance-stdlib', '2.0.0', :into => secondary_dir) }

      it "should fail if a module exists twice in the modpath" do
        expect(subject).to include :result => :failure
      end
    end

    context "when options[:version] is specified" do
      def options
        super.merge(:version => '1.0.0')
      end

      it "should uninstall the module if the version matches" do
        expect(subject[:affected_modules].length).to eq(1)
        expect(subject[:affected_modules].first.version).to eq("1.0.0")
      end

      context 'but not matched' do
        def options
          super.merge(:version => '2.0.0')
        end

        it "should not uninstall the module if the version does not match" do
          expect(subject).to include :result => :failure
        end
      end
    end

    context "when the module metadata is missing" do
      before { File.unlink(File.join(primary_dir, 'stdlib', 'metadata.json')) }

      it "should not uninstall the module" do
        expect(application.run[:result]).to eq(:failure)
      end
    end

    context "when the module has local changes" do
      before do
        mark_changed(File.join(primary_dir, 'stdlib'))
      end

      it "should not uninstall the module" do
        expect(subject).to include :result => :failure
      end
    end

    context "when uninstalling the module will cause broken dependencies" do
      before { preinstall('pmtacceptance-apache', '0.10.0') }

      it "should not uninstall the module" do
        expect(subject).to include :result => :failure
      end
    end

    context 'with --ignore-changes' do
      def options
        super.merge(:ignore_changes => true)
      end

      context 'with local changes' do
        before do
          mark_changed(File.join(primary_dir, 'stdlib'))
        end

        it 'overwrites the installed module with the greatest version matching that range' do
          expect(subject).to include :result => :success
        end
      end

      context 'without local changes' do
        it 'overwrites the installed module with the greatest version matching that range' do
          expect(subject).to include :result => :success
        end
      end
    end

    context "when using the --force flag" do

      def options
        super.merge(:force => true)
      end

      context "with local changes" do
        before do
          mark_changed(File.join(primary_dir, 'stdlib'))
        end

        it "should ignore local changes" do
          expect(subject[:affected_modules].length).to eq(1)
          expect(subject[:affected_modules].first.forge_name).to eq("pmtacceptance/stdlib")
        end
      end

      context "while depended upon" do
        before { preinstall('pmtacceptance-apache', '0.10.0') }

        it "should ignore broken dependencies" do
          expect(subject[:affected_modules].length).to eq(1)
          expect(subject[:affected_modules].first.forge_name).to eq("pmtacceptance/stdlib")
        end
      end
    end
  end

  context 'when in FIPS mode...' do
    it 'module uninstaller refuses to run' do
      Facter.stubs(:value).with(:fips_enabled).returns(true)
      expect {application.run}.to raise_error(/Module uninstall is prohibited in FIPS mode/)
    end 
  end

end
