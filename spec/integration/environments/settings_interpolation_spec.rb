require 'pp'
require 'spec_helper'

module SettingsInterpolationSpec
describe "interpolating $environment" do
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
      expect(@logs).to have_matching_log(/cannot interpolate \$environment within '#{setting}'.*Its value will remain #{Regexp.escape(expected)}/)
    end
  end

  context "when environmentpath is set" do
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

    it "raises validation error parsing a puppet.conf with a $environment in the default_manifest" do
      value = "$confdir/manifests/$environment"
      expected = "$confdir/manifests/$environment"

      set_puppet_conf(confdir, <<-EOF)
        default_manifest=#{value}
      EOF

      expect {
        Puppet.initialize_settings(cmdline_args)
      }.to raise_error(Puppet::Settings::ValidationError, /cannot interpolate '\$environment'.*within.*default_manifest/)
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

  def assert_does_interpolate_environment(setting, value, expected_interpolation)
    set_puppet_conf(confdir, <<-EOF)
      #{setting}=#{value}
    EOF

    Puppet.initialize_settings(cmdline_args)
    expect(Puppet[:environmentpath]).to be_empty
    expect(Puppet[setting.intern]).to eq(expected_interpolation)
    expect(@logs).to be_empty
  end

  context "when environmentpath is not set" do
    it "does interpolate $environment in basemodulepath" do
      value = "$confdir/environments/$environment/modules:$confdir/environments/$environment/other_modules"
      expected = "#{confdir}/environments/production/modules:#{confdir}/environments/production/other_modules"
      assert_does_interpolate_environment("basemodulepath", value, expected)
    end

    it "still raises a validation error parsing a puppet.conf with a $environment in default_manifest" do
      value = "$confdir/manifests/$environment"
      expected = "#{confdir}/manifests/$environment"
      expect {
        assert_does_interpolate_environment("default_manifest", value, expected)
      }.to raise_error(Puppet::Settings::ValidationError, /cannot interpolate '\$environment'.*within.*default_manifest/)
    end

    it "raises something" do
      value = expected = "whatareyouthinking$environment"
      expect {
        assert_does_interpolate_environment("environment", value, expected)
      }.to raise_error(SystemStackError, /stack level too deep/)
    end
  end

  def set_puppet_conf(confdir, settings)
    File.open(File.join(confdir, "puppet.conf"), "w") do |f|
      f.puts(settings)
    end
  end
end
end
