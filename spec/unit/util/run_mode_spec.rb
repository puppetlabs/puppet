#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Util::RunMode do
  before do
    @run_mode = Puppet::Util::RunMode.new('fake')
  end

  describe Puppet::Util::UnixRunMode, :unless => Puppet.features.microsoft_windows? do
    before do
      @run_mode = Puppet::Util::UnixRunMode.new('fake')
    end

    describe "#conf_dir" do
      it "has confdir /etc/puppetlabs/puppet when run as root" do
        as_root { expect(@run_mode.conf_dir).to eq(File.expand_path('/etc/puppetlabs/puppet')) }
      end

      it "has confdir ~/.puppetlabs/etc/puppet when run as non-root" do
        as_non_root { expect(@run_mode.conf_dir).to eq(File.expand_path('~/.puppetlabs/etc/puppet')) }
      end

      context "master run mode" do
        before do
          @run_mode = Puppet::Util::UnixRunMode.new('master')
        end
        it "has confdir ~/.puppetlabs/etc/puppet when run as non-root and master run mode" do
          as_non_root { expect(@run_mode.conf_dir).to eq(File.expand_path('~/.puppetlabs/etc/puppet')) }
        end
      end

      it "fails when asking for the conf_dir as non-root and there is no $HOME" do
        as_non_root do
          without_home do
            expect { @run_mode.conf_dir }.to raise_error ArgumentError, /couldn't find HOME/
          end
        end
      end
    end

    describe "#code_dir" do
      it "has codedir /etc/puppetlabs/code when run as root" do
        as_root { expect(@run_mode.code_dir).to eq(File.expand_path('/etc/puppetlabs/code')) }
      end

      it "has codedir ~/.puppetlabs/etc/code when run as non-root" do
        as_non_root { expect(@run_mode.code_dir).to eq(File.expand_path('~/.puppetlabs/etc/code')) }
      end

      context "master run mode" do
        before do
          @run_mode = Puppet::Util::UnixRunMode.new('master')
        end

        it "has codedir ~/.puppetlabs/etc/code when run as non-root and master run mode" do
          as_non_root { expect(@run_mode.code_dir).to eq(File.expand_path('~/.puppetlabs/etc/code')) }
        end
      end

      it "fails when asking for the code_dir as non-root and there is no $HOME" do
        as_non_root do
          without_home do
            expect { @run_mode.code_dir }.to raise_error ArgumentError, /couldn't find HOME/
          end
        end
      end
    end

    describe "#var_dir" do
      it "has vardir /opt/puppetlabs/puppet/cache when run as root" do
        as_root { expect(@run_mode.var_dir).to eq(File.expand_path('/opt/puppetlabs/puppet/cache')) }
      end

      it "has vardir ~/.puppetlabs/opt/puppet/cache when run as non-root" do
        as_non_root { expect(@run_mode.var_dir).to eq(File.expand_path('~/.puppetlabs/opt/puppet/cache')) }
      end

      it "fails when asking for the var_dir as non-root and there is no $HOME" do
        as_non_root do
          without_home do
            expect { @run_mode.var_dir }.to raise_error ArgumentError, /couldn't find HOME/
          end
        end
      end
    end

    describe "#log_dir" do
      describe "when run as root" do
        it "has logdir /var/log/puppetlabs/puppet" do
          as_root { expect(@run_mode.log_dir).to eq(File.expand_path('/var/log/puppetlabs/puppet')) }
        end
      end

      describe "when run as non-root" do
        it "has default logdir ~/.puppetlabs/var/log" do
          as_non_root { expect(@run_mode.log_dir).to eq(File.expand_path('~/.puppetlabs/var/log')) }
        end

        it "fails when asking for the log_dir and there is no $HOME" do
          as_non_root do
            without_home do
              expect { @run_mode.log_dir }.to raise_error ArgumentError, /couldn't find HOME/
            end
          end
        end
      end
    end

    describe "#run_dir" do
      describe "when run as root" do
        it "has rundir /var/run/puppetlabs" do
          as_root { expect(@run_mode.run_dir).to eq(File.expand_path('/var/run/puppetlabs')) }
        end
      end

      describe "when run as non-root" do
        it "has default rundir ~/.puppetlabs/var/run" do
          as_non_root { expect(@run_mode.run_dir).to eq(File.expand_path('~/.puppetlabs/var/run')) }
        end

        it "fails when asking for the run_dir and there is no $HOME" do
          as_non_root do
            without_home do
              expect { @run_mode.run_dir }.to raise_error ArgumentError, /couldn't find HOME/
            end
          end
        end
      end
    end
  end

  describe Puppet::Util::WindowsRunMode, :if => Puppet.features.microsoft_windows? do
    before do
      if not Dir.const_defined? :COMMON_APPDATA
        Dir.const_set :COMMON_APPDATA, "/CommonFakeBase"
        @remove_const = true
      end
      @run_mode = Puppet::Util::WindowsRunMode.new('fake')
    end

    after do
      if @remove_const
        Dir.send :remove_const, :COMMON_APPDATA
      end
    end

    describe "#conf_dir" do
      it "has confdir ending in Puppetlabs/puppet/etc when run as root" do
        as_root { expect(@run_mode.conf_dir).to eq(File.expand_path(File.join(Dir::COMMON_APPDATA, "PuppetLabs", "puppet", "etc"))) }
      end

      it "has confdir in ~/.puppetlabs/etc/puppet when run as non-root" do
        as_non_root { expect(@run_mode.conf_dir).to eq(File.expand_path("~/.puppetlabs/etc/puppet")) }
      end

      it "fails when asking for the conf_dir as non-root and there is no %HOME%, %HOMEDRIVE%, and %USERPROFILE%" do
        as_non_root do
          without_env('HOME') do
            without_env('HOMEDRIVE') do
              without_env('USERPROFILE') do
                expect { @run_mode.conf_dir }.to raise_error ArgumentError, /couldn't find HOME/
              end
            end
          end
        end
      end
    end

    describe "#code_dir" do
      it "has codedir ending in PuppetLabs/code when run as root" do
        as_root { expect(@run_mode.code_dir).to eq(File.expand_path(File.join(Dir::COMMON_APPDATA, "PuppetLabs", "code"))) }
      end

      it "has codedir in ~/.puppetlabs/etc/code when run as non-root" do
        as_non_root { expect(@run_mode.code_dir).to eq(File.expand_path("~/.puppetlabs/etc/code")) }
      end

      it "fails when asking for the code_dir as non-root and there is no %HOME%, %HOMEDRIVE%, and %USERPROFILE%" do
        as_non_root do
          without_env('HOME') do
            without_env('HOMEDRIVE') do
              without_env('USERPROFILE') do
                expect { @run_mode.code_dir }.to raise_error ArgumentError, /couldn't find HOME/
              end
            end
          end
        end
      end
    end

    describe "#var_dir" do
      it "has vardir ending in PuppetLabs/puppet/cache when run as root" do
        as_root { expect(@run_mode.var_dir).to eq(File.expand_path(File.join(Dir::COMMON_APPDATA, "PuppetLabs", "puppet", "cache"))) }
      end

      it "has vardir in ~/.puppetlabs/opt/puppet/cache when run as non-root" do
        as_non_root { expect(@run_mode.var_dir).to eq(File.expand_path("~/.puppetlabs/opt/puppet/cache")) }
      end

      it "fails when asking for the conf_dir as non-root and there is no %HOME%, %HOMEDRIVE%, and %USERPROFILE%" do
        as_non_root do
          without_env('HOME') do
            without_env('HOMEDRIVE') do
              without_env('USERPROFILE') do
                expect { @run_mode.var_dir }.to raise_error ArgumentError, /couldn't find HOME/
              end
            end
          end
        end
      end
    end

    describe "#log_dir" do
      describe "when run as root" do
        it "has logdir ending in PuppetLabs/puppet/var/log" do
          as_root { expect(@run_mode.log_dir).to eq(File.expand_path(File.join(Dir::COMMON_APPDATA, "PuppetLabs", "puppet", "var", "log"))) }
        end
      end

      describe "when run as non-root" do
        it "has default logdir ~/.puppetlabs/var/log" do
          as_non_root { expect(@run_mode.log_dir).to eq(File.expand_path('~/.puppetlabs/var/log')) }
        end

        it "fails when asking for the log_dir and there is no $HOME" do
          as_non_root do
            without_env('HOME') do
              without_env('HOMEDRIVE') do
                without_env('USERPROFILE') do
                  expect { @run_mode.log_dir }.to raise_error ArgumentError, /couldn't find HOME/
                end
              end
            end
          end
        end
      end
    end

    describe "#run_dir" do
      describe "when run as root" do
        it "has rundir ending in PuppetLabs/puppet/var/run" do
          as_root { expect(@run_mode.run_dir).to eq(File.expand_path(File.join(Dir::COMMON_APPDATA, "PuppetLabs", "puppet", "var", "run"))) }
        end
      end

      describe "when run as non-root" do
        it "has default rundir ~/.puppetlabs/var/run" do
          as_non_root { expect(@run_mode.run_dir).to eq(File.expand_path('~/.puppetlabs/var/run')) }
        end

        it "fails when asking for the run_dir and there is no $HOME" do
          as_non_root do
            without_env('HOME') do
              without_env('HOMEDRIVE') do
                without_env('USERPROFILE') do
                  expect { @run_mode.run_dir }.to raise_error ArgumentError, /couldn't find HOME/
                end
              end
            end
          end
        end
      end
    end

    describe "#without_env internal helper with UTF8 characters" do
      let(:varname) { "\u16A0\u16C7\u16BB\u16EB\u16D2\u16E6\u16A6\u16EB\u16A0\u16B1\u16A9\u16A0\u16A2\u16B1\u16EB\u16A0\u16C1\u16B1\u16AA\u16EB\u16B7\u16D6\u16BB\u16B9\u16E6\u16DA\u16B3\u16A2\u16D7" }
      let(:rune_utf8) { "\u16A0\u16C7\u16BB\u16EB\u16D2\u16E6\u16A6\u16EB\u16A0\u16B1\u16A9\u16A0\u16A2\u16B1\u16EB\u16A0\u16C1\u16B1\u16AA\u16EB\u16B7\u16D6\u16BB\u16B9\u16E6\u16DA\u16B3\u16A2\u16D7" }

      before do
        Puppet::Util::Windows::Process.set_environment_variable(varname, rune_utf8)
      end

      it "removes environment variables within the block with UTF8 name" do
        without_env(varname) do
          expect(ENV[varname]).to be(nil)
        end
      end

      it "restores UTF8 characters in environment variable values" do
        without_env(varname) do
          Puppet::Util::Windows::Process.set_environment_variable(varname, 'bad value')
        end

        envhash = Puppet::Util::Windows::Process.get_environment_strings
        expect(envhash[varname]).to eq(rune_utf8)
      end
    end
  end

  def as_root
    Puppet.features.stubs(:root?).returns(true)
    yield
  end

  def as_non_root
    Puppet.features.stubs(:root?).returns(false)
    yield
  end

  def without_env(name, &block)
    saved = Puppet::Util.get_env(name)
    Puppet::Util.set_env(name, nil)
    yield
  ensure
    Puppet::Util.set_env(name, saved)
  end

  def without_home(&block)
    without_env('HOME', &block)
  end
end
