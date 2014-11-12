require 'spec_helper'

describe "directory environments" do
  let(:args) { ['--configprint', 'modulepath', '--environment', 'direnv'] }
  let(:puppet) do
    app = Puppet::Application[:apply]
    app.stubs(:command_line).returns(stub('command_line', :args => []))
    app
  end

  context "with a single directory environmentpath" do
    before(:each) do
      environmentdir = PuppetSpec::Files.tmpdir('envpath')
      Puppet[:environmentpath] = environmentdir
      FileUtils.mkdir_p(environmentdir + "/direnv/modules")
    end

    it "config prints the environments modulepath" do
      Puppet.settings.initialize_global_settings(args)
      expect do
        expect { puppet.run }.to exit_with(0)
      end.to have_printed('/direnv/modules')
    end

    it "config prints the cli --modulepath despite environment" do
      args << '--modulepath' << '/completely/different'
      Puppet.settings.initialize_global_settings(args)
      expect do
        expect { puppet.run }.to exit_with(0)
      end.to have_printed('/completely/different')
    end
  end

  context "with an environmentpath having multiple directories" do
    let(:args) { ['--configprint', 'modulepath', '--environment', 'otherdirenv'] }

    before(:each) do
      envdir1 = File.join(Puppet[:confdir], 'env1')
      envdir2 = File.join(Puppet[:confdir], 'env2')
      Puppet[:environmentpath] = [envdir1, envdir2].join(File::PATH_SEPARATOR)
      FileUtils.mkdir_p(envdir2 + "/otherdirenv/modules")
    end

    it "config prints a directory environment modulepath" do
      Puppet.settings.initialize_global_settings(args)
      expect do
        expect { puppet.run }.to exit_with(0)
      end.to have_printed('otherdirenv/modules')
    end
  end
end
