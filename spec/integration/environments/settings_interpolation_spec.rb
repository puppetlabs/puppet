require 'pp'
require 'spec_helper'
require 'puppet_spec/settings'

module SettingsInterpolationSpec
describe "interpolating $environment" do
  include PuppetSpec::Settings

  let(:confdir) { Puppet[:confdir] }
  let(:cmdline_args) { ['--confdir', confdir, '--vardir', Puppet[:vardir], '--hiera_config', Puppet[:hiera_config]] }

  before(:each) do
    FileUtils.mkdir_p(confdir)
  end

  shared_examples_for "a setting that does not interpolate $environment" do

    before(:each) do
      set_puppet_conf(confdir, <<-EOF)
        environmentpath=$confdir/environments
        #{setting}=#{value}
      EOF
    end

    it "does not interpolate $environment" do
      Puppet.initialize_settings(cmdline_args)
      expect(Puppet[:environmentpath]).to eq("#{confdir}/environments")
      expect(Puppet[setting.intern]).to eq(expected)
    end

    it "displays the interpolated value in the warning" do
      Puppet.initialize_settings(cmdline_args)
      Puppet[setting.intern]
      expect(@logs).to have_matching_log(/cannot interpolate \$environment within '#{setting}'.*Its value will remain #{Regexp.escape(expected)}/)
    end
  end

  describe "config_version" do
    it "interpolates $environment" do
      envname = 'testing'
      setting = 'config_version'
      value = '/some/script $environment'
      expected = "#{File.expand_path('/some/script')} testing"

      set_puppet_conf(confdir, <<-EOF)
        environmentpath=$confdir/environments
        environment=#{envname}
      EOF

      set_environment_conf("#{confdir}/environments", envname, <<-EOF)
        #{setting}=#{value}
      EOF

      Puppet.initialize_settings(cmdline_args)
      expect(Puppet[:environmentpath]).to eq("#{confdir}/environments")
      environment = Puppet.lookup(:environments).get(envname)
      expect(environment.config_version).to eq(expected)
      expect(@logs).to be_empty
    end
  end

  describe "basemodulepath" do
    let(:setting) { "basemodulepath" }
    let(:value) { "$confdir/environments/$environment/modules:$confdir/environments/$environment/other_modules" }
    let(:expected) { "#{confdir}/environments/$environment/modules:#{confdir}/environments/$environment/other_modules" }

    it_behaves_like "a setting that does not interpolate $environment"

    it "logs a single warning for multiple instaces of $environment in the setting" do
      set_puppet_conf(confdir, <<-EOF)
        environmentpath=$confdir/environments
        #{setting}=#{value}
      EOF

      Puppet.initialize_settings(cmdline_args)
      expect(@logs.map(&:to_s).grep(/cannot interpolate \$environment within '#{setting}'/).count).to eq(1)
    end
  end

  describe "environment" do
    let(:setting) { "environment" }
    let(:value) { "whatareyouthinking$environment" }
    let(:expected) { value }

    it_behaves_like "a setting that does not interpolate $environment"
  end

  describe "the default_manifest" do
    let(:setting) { "default_manifest" }
    let(:value) { "$confdir/manifests/$environment" }
    let(:expected) { "#{confdir}/manifests/$environment" }

    it_behaves_like "a setting that does not interpolate $environment"
  end

  it "does not interpolate $environment and logs a warning when interpolating environmentpath" do
    setting = 'environmentpath'
    value = "$confdir/environments/$environment"
    expected = "#{confdir}/environments/$environment"

    set_puppet_conf(confdir, <<-EOF)
      #{setting}=#{value}
    EOF

    Puppet.initialize_settings(cmdline_args)
    expect(Puppet[setting.intern]).to eq(expected)
    expect(@logs).to have_matching_log(/cannot interpolate \$environment within '#{setting}'/)
  end
end
end
