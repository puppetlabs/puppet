require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/module_tool/shared_functions'
require 'puppet_spec/module_tool/stub_source'

require 'tmpdir'

describe Puppet::ModuleTool::Applications::Installer do
  include PuppetSpec::ModuleTool::SharedFunctions
  include PuppetSpec::Files
  include PuppetSpec::Fixtures

  before do
    FileUtils.mkdir_p(primary_dir)
    FileUtils.mkdir_p(secondary_dir)
  end

  let(:vardir)        { tmpdir('installer') }
  let(:primary_dir)   { File.join(vardir, "primary") }
  let(:secondary_dir) { File.join(vardir, "secondary") }
  let(:remote_source) { PuppetSpec::ModuleTool::StubSource.new }

  let(:install_dir) do
    mock("Puppet::ModuleTool::InstallDirectory").tap do |dir|
      dir.stubs(:prepare)
      dir.stubs(:target).returns(primary_dir)
    end
  end

  before do
    SemanticPuppet::Dependency.clear_sources
    installer = Puppet::ModuleTool::Applications::Installer.any_instance
    installer.stubs(:module_repository).returns(remote_source)
  end

  if Puppet.features.microsoft_windows?
    before :each do
      Puppet.settings.stubs(:[])
      Puppet.settings.stubs(:[]).with(:module_working_dir).returns(Dir.mktmpdir('installertmp'))
    end
  end

  def installer(modname, target_dir, options)
    Puppet::ModuleTool.set_option_defaults(options)
    Puppet::ModuleTool::Applications::Installer.new(modname, target_dir, options)
  end

  let(:environment) do
    Puppet.lookup(:current_environment).override_with(
      :vardir     => vardir,
      :modulepath => [ primary_dir, secondary_dir ]
    )
  end

  context '#run' do
    let(:module) { 'pmtacceptance-stdlib' }

    def options
      { :environment => environment }
    end

    let(:application) { installer(self.module, install_dir, options) }
    subject { application.run }

    it 'installs the specified module' do
      expect(subject).to include :result => :success
      graph_should_include 'pmtacceptance-stdlib', nil => v('4.1.0')
    end

    context 'with a tarball file' do
      let(:module) { fixtures('stdlib.tgz') }

      it 'installs the specified tarball' do
        expect(subject).to include :result => :success
        graph_should_include 'puppetlabs-stdlib', nil => v('3.2.0')
      end

      context 'with --ignore-dependencies' do
        def options
          super.merge(:ignore_dependencies => true)
        end

        it 'installs the specified tarball' do
          remote_source.expects(:fetch).never
          expect(subject).to include :result => :success
          graph_should_include 'puppetlabs-stdlib', nil => v('3.2.0')
        end
      end

      context 'with dependencies' do
        let(:module) { fixtures('java.tgz') }

        it 'installs the specified tarball' do
          expect(subject).to include :result => :success
          graph_should_include 'puppetlabs-java', nil => v('1.0.0')
          graph_should_include 'puppetlabs-stdlib', nil => v('4.1.0')
        end

        context 'with --ignore-dependencies' do
          def options
            super.merge(:ignore_dependencies => true)
          end

          it 'installs the specified tarball without dependencies' do
            remote_source.expects(:fetch).never
            expect(subject).to include :result => :success
            graph_should_include 'puppetlabs-java', nil => v('1.0.0')
            graph_should_include 'puppetlabs-stdlib', nil
          end
        end
      end
    end

    context 'with dependencies' do
      let(:module) { 'pmtacceptance-apache' }

      it 'installs the specified module and its dependencies' do
        expect(subject).to include :result => :success
        graph_should_include 'pmtacceptance-apache', nil => v('0.10.0')
        graph_should_include 'pmtacceptance-stdlib', nil => v('4.1.0')
      end

      context 'and using --ignore_dependencies' do
        def options
          super.merge(:ignore_dependencies => true)
        end

        it 'installs only the specified module' do
          expect(subject).to include :result => :success
          graph_should_include 'pmtacceptance-apache', nil => v('0.10.0')
          graph_should_include 'pmtacceptance-stdlib', nil
        end
      end

      context 'that are already installed' do
        context 'and satisfied' do
          before { preinstall('pmtacceptance-stdlib', '4.1.0') }

          it 'installs only the specified module' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-apache', nil => v('0.10.0')
            graph_should_include 'pmtacceptance-stdlib', :path => primary_dir
          end

          context '(outdated but suitable version)' do
            before { preinstall('pmtacceptance-stdlib', '2.4.0') }

            it 'installs only the specified module' do
              expect(subject).to include :result => :success
              graph_should_include 'pmtacceptance-apache', nil => v('0.10.0')
              graph_should_include 'pmtacceptance-stdlib', v('2.4.0') => v('2.4.0'), :path => primary_dir
            end
          end

          context '(outdated and unsuitable version)' do
            before { preinstall('pmtacceptance-stdlib', '1.0.0') }

            it 'installs a version that is compatible with the installed dependencies' do
              expect(subject).to include :result => :success
              graph_should_include 'pmtacceptance-apache', nil => v('0.0.4')
              graph_should_include 'pmtacceptance-stdlib', nil
            end
          end
        end

        context 'but not satisfied' do
          let(:module) { 'pmtacceptance-keystone' }

          def options
            super.merge(:version => '2.0.0')
          end

          before { preinstall('pmtacceptance-mysql', '2.1.0') }

          it 'installs only the specified module' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-keystone', nil => v('2.0.0')
            graph_should_include 'pmtacceptance-mysql', v('2.1.0') => v('2.1.0')
            graph_should_include 'pmtacceptance-stdlib', nil
          end
        end
      end

      context 'that are already installed in other modulepath directories' do
        before { preinstall('pmtacceptance-stdlib', '1.0.0', :into => secondary_dir) }
        let(:module) { 'pmtacceptance-apache' }

        context 'without dependency updates' do
          it 'installs the module only' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-apache', nil => v('0.0.4')
            graph_should_include 'pmtacceptance-stdlib', nil
          end
        end

        context 'with dependency updates' do
          before { preinstall('pmtacceptance-stdlib', '2.0.0', :into => secondary_dir) }

          it 'installs the module and upgrades dependencies in-place' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-apache', nil => v('0.10.0')
            graph_should_include 'pmtacceptance-stdlib', v('2.0.0') => v('2.6.0'), :path => secondary_dir
          end
        end
      end
    end

    context 'with a specified' do

      context 'version' do
        def options
          super.merge(:version => '3.0.0')
        end

        it 'installs the specified release (or a prerelease thereof)' do
          expect(subject).to include :result => :success
          graph_should_include 'pmtacceptance-stdlib', nil => v('3.0.0')
        end
      end

      context 'version range' do
        def options
          super.merge(:version => '3.x')
        end

        it 'installs the greatest available version matching that range' do
          expect(subject).to include :result => :success
          graph_should_include 'pmtacceptance-stdlib', nil => v('3.2.0')
        end
      end
    end

    context 'when depended upon' do
      before { preinstall('pmtacceptance-keystone', '2.1.0') }
      let(:module)  { 'pmtacceptance-mysql' }

      it 'installs the greatest available version meeting the dependency constraints' do
        expect(subject).to include :result => :success
        graph_should_include 'pmtacceptance-mysql', nil => v('0.9.0')
      end

      context 'with a --version that can satisfy' do
        def options
          super.merge(:version => '0.8.0')
        end

        it 'installs the greatest available version satisfying both constraints' do
          expect(subject).to include :result => :success
          graph_should_include 'pmtacceptance-mysql', nil => v('0.8.0')
        end
      end

      context 'with a --version that cannot satisfy' do
        def options
          super.merge(:version => '> 1.0.0')
        end

        it 'fails to install, since there is no version that can satisfy both constraints' do
          expect(subject).to include :result => :failure
        end

        context 'with --ignore-dependencies' do
          def options
            super.merge(:ignore_dependencies => true)
          end

          it 'fails to install, since ignore_dependencies should still respect dependencies from installed modules' do
            expect(subject).to include :result => :failure
          end
        end

        context 'with --force' do
          def options
            super.merge(:force => true)
          end

          it 'installs the greatest available version, ignoring dependencies' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-mysql', nil => v('2.1.0')
          end
        end
      end
    end

    context 'when already installed' do
      before { preinstall('pmtacceptance-stdlib', '1.0.0') }

      context 'but matching the requested version' do
        it 'does nothing, since the installed version satisfies' do
          expect(subject).to include :result => :noop
        end

        context 'with --force' do
          def options
            super.merge(:force => true)
          end

          it 'does reinstall the module' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-stdlib', v('1.0.0') => v('4.1.0')
          end
        end

        context 'with local changes' do
          before do
            release = application.send(:installed_modules)['pmtacceptance-stdlib']
            mark_changed(release.mod.path)
          end

          it 'does nothing, since local changes do not affect that' do
            expect(subject).to include :result => :noop
          end

          context 'with --force' do
            def options
              super.merge(:force => true)
            end

            it 'does reinstall the module, since --force ignores local changes' do
              expect(subject).to include :result => :success
              graph_should_include 'pmtacceptance-stdlib', v('1.0.0') => v('4.1.0')
            end
          end
        end
      end

      context 'but not matching the requested version' do
        def options
          super.merge(:version => '2.x')
        end

        it 'fails to install the module, since it is already installed' do
          expect(subject).to include :result => :failure
          expect(subject[:error]).to include :oneline => "'pmtacceptance-stdlib' (v2.x) requested; 'pmtacceptance-stdlib' (v1.0.0) already installed"
        end

        context 'with --force' do
          def options
            super.merge(:force => true)
          end

          it 'installs the greatest version matching the new version range' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-stdlib', v('1.0.0') => v('2.6.0')
          end
        end
      end
    end

    context 'when a module with the same name is already installed' do
      let(:module) { 'pmtacceptance-stdlib' }
      before { preinstall('puppetlabs-stdlib', '4.1.0') }

      it 'fails to install, since two modules with the same name cannot be installed simultaneously' do
        expect(subject).to include :result => :failure
      end

      context 'using --force' do
        def options
          super.merge(:force => true)
        end

        it 'overwrites the existing module with the greatest version of the requested module' do
          expect(subject).to include :result => :success
          graph_should_include 'pmtacceptance-stdlib', nil => v('4.1.0')
        end
      end
    end

    context 'when in FIPS mode...' do
      it 'module installer refuses to run' do
        Facter.stubs(:value).with(:fips_enabled).returns(true)
        expect {application.run}.to raise_error(/Module install is prohibited in FIPS mode./)
      end 
    end

  end

end
