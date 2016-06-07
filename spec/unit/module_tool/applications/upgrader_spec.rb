require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/module_tool/shared_functions'
require 'puppet_spec/module_tool/stub_source'
require 'semver'

describe Puppet::ModuleTool::Applications::Upgrader do
  include PuppetSpec::ModuleTool::SharedFunctions
  include PuppetSpec::Files

  before do
    FileUtils.mkdir_p(primary_dir)
    FileUtils.mkdir_p(secondary_dir)
  end

  let(:vardir)   { tmpdir('upgrader') }
  let(:primary_dir) { File.join(vardir, "primary") }
  let(:secondary_dir) { File.join(vardir, "secondary") }
  let(:remote_source) { PuppetSpec::ModuleTool::StubSource.new }

  let(:environment) do
    Puppet.lookup(:current_environment).override_with(
      :vardir     => vardir,
      :modulepath => [ primary_dir, secondary_dir ]
    )
  end

  before do
    Semantic::Dependency.clear_sources
    installer = Puppet::ModuleTool::Applications::Upgrader.any_instance
    installer.stubs(:module_repository).returns(remote_source)
  end

  def upgrader(name, options = {})
    Puppet::ModuleTool.set_option_defaults(options)
    Puppet::ModuleTool::Applications::Upgrader.new(name, options)
  end

  describe '#run' do
    let(:module) { 'pmtacceptance-stdlib' }

    def options
      { :environment => environment }
    end

    let(:application) { upgrader(self.module, options) }
    subject { application.run }

    it 'fails if the module is not already installed' do
      expect(subject).to include :result => :failure
      expect(subject[:error]).to include :oneline => "Could not upgrade '#{self.module}'; module is not installed"
    end

    context 'for an installed module' do
      context 'with only one version' do
        before { preinstall('puppetlabs-oneversion', '0.0.1') }
        let(:module) { 'puppetlabs-oneversion' }

        it 'declines to upgrade' do
          expect(subject).to include :result => :noop
          expect(subject[:error][:multiline]).to match(/already the latest version/)
        end
      end

      context 'without dependencies' do
        before { preinstall('pmtacceptance-stdlib', '1.0.0') }

        context 'without options' do
          it 'properly upgrades the module to the greatest version' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-stdlib', v('1.0.0') => v('4.1.0')
          end
        end

        context 'with version range' do
          def options
            super.merge(:version => '3.x')
          end

          context 'not matching the installed version' do
            it 'properly upgrades the module to the greatest version within that range' do
              expect(subject).to include :result => :success
              graph_should_include 'pmtacceptance-stdlib', v('1.0.0') => v('3.2.0')
            end
          end

          context 'matching the installed version' do
            context 'with more recent version' do
              before { preinstall('pmtacceptance-stdlib', '3.0.0')}

              it 'properly upgrades the module to the greatest version within that range' do
                expect(subject).to include :result => :success
                graph_should_include 'pmtacceptance-stdlib', v('3.0.0') => v('3.2.0')
              end
            end

            context 'without more recent version' do
              before { preinstall('pmtacceptance-stdlib', '3.2.0')}

              context 'without options' do
                it 'declines to upgrade' do
                  expect(subject).to include :result => :noop
                  expect(subject[:error][:multiline]).to match(/already the latest version/)
                end
              end

              context 'with --force' do
                def options
                  super.merge(:force => true)
                end

                it 'overwrites the installed module with the greatest version matching that range' do
                  expect(subject).to include :result => :success
                  graph_should_include 'pmtacceptance-stdlib', v('3.2.0') => v('3.2.0')
                end
              end
            end
          end
        end
      end

      context 'that is depended upon' do
        # pmtacceptance-keystone depends on pmtacceptance-mysql  >=0.6.1 <1.0.0
        before { preinstall('pmtacceptance-keystone', '2.1.0') }
        before { preinstall('pmtacceptance-mysql', '0.9.0') }

        let(:module) { 'pmtacceptance-mysql' }

        context 'and out of date' do
          before { preinstall('pmtacceptance-mysql', '0.8.0') }

          it 'properly upgrades to the greatest version matching the dependency' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-mysql', v('0.8.0') => v('0.9.0')
          end
        end

        context 'and up to date' do
          it 'declines to upgrade' do
            expect(subject).to include :result => :failure
          end
        end

        context 'when specifying a violating version range' do
          def options
            super.merge(:version => '2.1.0')
          end

          it 'fails to upgrade the module' do
            # TODO: More helpful error message?
            expect(subject).to include :result => :failure
            expect(subject[:error]).to include :oneline => "Could not upgrade '#{self.module}' (v0.9.0 -> v2.1.0); no version satisfies all dependencies"
          end

          context 'using --force' do
            def options
              super.merge(:force => true)
            end

            it 'overwrites the installed module with the specified version' do
              expect(subject).to include :result => :success
              graph_should_include 'pmtacceptance-mysql', v('0.9.0') => v('2.1.0')
            end
          end
        end
      end

      context 'with local changes' do
        before { preinstall('pmtacceptance-stdlib', '1.0.0') }
        before do
          release = application.send(:installed_modules)['pmtacceptance-stdlib']
          mark_changed(release.mod.path)
        end

        it 'fails to upgrade' do
          expect(subject).to include :result => :failure
          expect(subject[:error]).to include :oneline => "Could not upgrade '#{self.module}'; module has had changes made locally"
        end

        context 'with --ignore-changes' do
          def options
            super.merge(:ignore_changes => true)
          end

          it 'overwrites the installed module with the greatest version matching that range' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-stdlib', v('1.0.0') => v('4.1.0')
          end
        end
      end

      context 'with dependencies' do
        context 'that are unsatisfied' do
          def options
            super.merge(:version => '0.1.1')
          end

          before { preinstall('pmtacceptance-apache', '0.0.3') }
          let(:module) { 'pmtacceptance-apache' }

          it 'upgrades the module and installs the missing dependencies' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.1.1')
            graph_should_include 'pmtacceptance-stdlib', nil => v('4.1.0'), :action => :install
          end
        end

        context 'with older major versions' do
          # pmtacceptance-apache 0.0.4 has no dependency on pmtacceptance-stdlib
          # the next available version (0.1.1) and all subsequent versions depend on pmtacceptance-stdlib >= 2.2.1
          before { preinstall('pmtacceptance-apache', '0.0.3') }
          before { preinstall('pmtacceptance-stdlib', '1.0.0') }
          let(:module) { 'pmtacceptance-apache' }

          it 'refuses to upgrade the installed dependency to a new major version, but upgrades the module to the greatest compatible version' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.0.4')
          end

          context 'using --ignore_dependencies' do
            def options
              super.merge(:ignore_dependencies => true)
            end

            it 'upgrades the module to the greatest available version' do
              expect(subject).to include :result => :success
              graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.10.0')
            end
          end
        end

        context 'with satisfying major versions' do
          before { preinstall('pmtacceptance-apache', '0.0.3') }
          before { preinstall('pmtacceptance-stdlib', '2.0.0') }
          let(:module) { 'pmtacceptance-apache' }

          it 'upgrades the module and its dependencies to their greatest compatible versions' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.10.0')
            graph_should_include 'pmtacceptance-stdlib', v('2.0.0') => v('2.6.0')
          end
        end

        context 'with satisfying versions' do
          before { preinstall('pmtacceptance-apache', '0.0.3') }
          before { preinstall('pmtacceptance-stdlib', '2.4.0') }
          let(:module) { 'pmtacceptance-apache' }

          it 'upgrades the module to the greatest available version' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.10.0')
            graph_should_include 'pmtacceptance-stdlib', nil
          end
        end

        context 'with current versions' do
          before { preinstall('pmtacceptance-apache', '0.0.3') }
          before { preinstall('pmtacceptance-stdlib', '2.6.0') }
          let(:module) { 'pmtacceptance-apache' }

          it 'upgrades the module to the greatest available version' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.10.0')
            graph_should_include 'pmtacceptance-stdlib', nil
          end
        end

        context 'with shared dependencies' do
          # bacula 0.0.3 depends on stdlib >= 2.2.0 and pmtacceptance/mysql >= 1.0.0
          # bacula 0.0.2 depends on stdlib >= 2.2.0 and pmtacceptance/mysql >= 0.0.1
          # bacula 0.0.1 depends on stdlib >= 2.2.0

          # keystone 2.1.0 depends on pmtacceptance/stdlib >= 2.5.0 and pmtacceptance/mysql >=0.6.1 <1.0.0

          before { preinstall('pmtacceptance-bacula', '0.0.1') }
          before { preinstall('pmtacceptance-mysql', '0.9.0') }
          before { preinstall('pmtacceptance-keystone', '2.1.0') }

          let(:module) { 'pmtacceptance-bacula' }

          it 'upgrades the module to the greatest version compatible with all other installed modules' do
            expect(subject).to include :result => :success
            graph_should_include 'pmtacceptance-bacula', v('0.0.1') => v('0.0.2')
          end

          context 'using --force' do
            def options
              super.merge(:force => true)
            end

            it 'upgrades the module to the greatest version available' do
              expect(subject).to include :result => :success
              graph_should_include 'pmtacceptance-bacula', v('0.0.1') => v('0.0.3')
            end
          end
        end

        context 'in other modulepath directories' do
          before { preinstall('pmtacceptance-apache', '0.0.3') }
          before { preinstall('pmtacceptance-stdlib', '1.0.0', :into => secondary_dir) }
          let(:module) { 'pmtacceptance-apache' }

          context 'with older major versions' do
            it 'upgrades the module to the greatest version compatible with the installed modules' do
              expect(subject).to include :result => :success
              graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.0.4')
              graph_should_include 'pmtacceptance-stdlib', nil
            end
          end

          context 'with satisfying major versions' do
            before { preinstall('pmtacceptance-stdlib', '2.0.0', :into => secondary_dir) }

            it 'upgrades the module and its dependencies to their greatest compatible versions, in-place' do
              expect(subject).to include :result => :success
              graph_should_include 'pmtacceptance-apache', v('0.0.3') => v('0.10.0')
              graph_should_include 'pmtacceptance-stdlib', v('2.0.0') => v('2.6.0'), :path => secondary_dir
            end
          end
        end
      end
    end
  end
end
