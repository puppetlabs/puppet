require 'spec_helper'

describe "directory environments" do
  let(:confdir) { Puppet[:confdir] }
  let(:args) { ['--configprint', 'modulepath', '--environment', 'direnv'] }
  let(:puppet) do
    app = Puppet::Application[:apply]
    app.stubs(:command_line).returns(stub('command_line', :args => []))
    app
  end

  context "with a single directory environmentpath" do
    before(:each) do
      environmentdir = PuppetSpec::Files.tmpdir('envpath')
      set_puppet_conf(confdir, <<-EOF)
      environmentpath = #{environmentdir}
      EOF
      FileUtils.mkdir_p(environmentdir + "/direnv/modules")
    end

    it "config prints the environments modulepath" do
      Puppet.settings.initialize_global_settings(args)
      expect do
        expect { puppet.run }.to exit_with(0)
      end.to have_printed('direnv/modules')
    end

    it "config prints the cli --modulepath despite environment" do
      args << '--modulepath' << 'completely/different'
      Puppet.settings.initialize_global_settings(args)
      expect do
        expect { puppet.run }.to exit_with(0)
      end.to have_printed('completely/different')
    end
  end

  context "with an environmentpath having multiple directories" do
    let(:args) { ['--configprint', 'modulepath', '--environment', 'otherdirenv'] }

    before(:each) do
      envdir1 = File.join(Puppet[:confdir], 'env1')
      envdir2 = File.join(Puppet[:confdir], 'env2')
      set_puppet_conf(confdir, <<-EOF)
      environmentpath = #{[envdir1, envdir2].join(File::PATH_SEPARATOR)}
      EOF
      FileUtils.mkdir_p(envdir2 + "/otherdirenv/modules")
    end

    it "config prints a directory environment modulepath" do
      Puppet.settings.initialize_global_settings(args)
      expect do
        expect { puppet.run }.to exit_with(0)
      end.to have_printed('otherdirenv/modules')
    end
  end

  def set_puppet_conf(confdir, settings)
    FileUtils.mkdir_p(confdir)
    write_file(File.join(confdir, "puppet.conf"), settings)
  end

  def write_file(file, contents)
    File.open(file, "w") do |f|
      f.puts(contents)
    end
  end
end
