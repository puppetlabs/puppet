#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet_spec/files'
require 'puppet_spec/compiler'

describe Puppet::Node::Facts::Facter do
  include PuppetSpec::Files
  include PuppetSpec::Compiler

  it "preserves case in fact values" do
    Facter.add(:downcase_test) do
      setcode do
        "AaBbCc"
      end
    end

    Facter.stubs(:reset)

    cat = compile_to_catalog('notify { $downcase_test: }',
                             Puppet::Node.indirection.find('foo'))
    expect(cat.resource("Notify[AaBbCc]")).to be
  end

  context "resolving file based facts" do
    let(:factdir) { tmpdir('factdir') }

    it "should resolve custom facts" do
      test_module = File.join(factdir, 'module', 'lib', 'facter')
      FileUtils.mkdir_p(test_module)

      File.open(File.join(test_module, 'custom.rb'), 'wb') { |file| file.write(<<-EOF)}
      Facter.add(:custom) do
        setcode do
          Facter.value('puppetversion')
        end
      end
      EOF

      Puppet.initialize_settings(['--modulepath', factdir])
      apply = Puppet::Application.find(:apply).new(stub('command_line', :subcommand_name => :apply, :args => ['--modulepath', factdir, '-e', 'notify { $custom: }']))

      expect do
        expect { apply.run }.to exit_with(0)
      end.to have_printed(Puppet.version)
    end

    it "should resolve external facts" do
      external_fact = File.join(factdir, 'external')

      if Puppet.features.microsoft_windows?
        external_fact += '.bat'
        File.open(external_fact, 'wb') { |file| file.write(<<-EOF)}
        @echo foo=bar
        EOF
      else
        File.open(external_fact, 'wb') { |file| file.write(<<-EOF)}
        #!/bin/sh
        echo "foo=bar"
        EOF

        Puppet::FileSystem.chmod(0755, external_fact)
      end

      Puppet.initialize_settings(['--pluginfactdest', factdir])
      apply = Puppet::Application.find(:apply).new(stub('command_line', :subcommand_name => :apply, :args => ['--pluginfactdest', factdir, '-e', 'notify { $foo: }']))

      expect do
        expect { apply.run }.to exit_with(0)
      end.to have_printed('bar')
    end
  end

  it "adds the puppetversion fact" do
    Facter.stubs(:reset)

    cat = compile_to_catalog('notify { $::puppetversion: }',
                             Puppet::Node.indirection.find('foo'))
    expect(cat.resource("Notify[#{Puppet.version.to_s}]")).to be
  end

  it "the agent_specified_environment fact is nil when not set" do
    expect do
      compile_to_catalog('notify { $::agent_specified_environment: }',
                         Puppet::Node.indirection.find('foo'))
    end.to raise_error(Puppet::PreformattedError)
  end

  it "adds the agent_specified_environment fact when set in puppet.conf" do
    FileUtils.mkdir_p(Puppet[:confdir])
    File.open(File.join(Puppet[:confdir], 'puppet.conf'), 'w') do |f|
      f.puts("environment=bar")
    end

    Puppet.initialize_settings
    cat = compile_to_catalog('notify { $::agent_specified_environment: }',
                             Puppet::Node.indirection.find('foo'))
    expect(cat.resource("Notify[bar]")).to be
  end

  it "adds the agent_specified_environment fact when set via command-line" do
    Puppet.initialize_settings(['--environment', 'bar'])
    cat = compile_to_catalog('notify { $::agent_specified_environment: }',
                             Puppet::Node.indirection.find('foo'))
    expect(cat.resource("Notify[bar]")).to be
  end

  it "adds the agent_specified_environment fact, preferring cli, when set in puppet.conf and via command-line" do
    FileUtils.mkdir_p(Puppet[:confdir])
    File.open(File.join(Puppet[:confdir], 'puppet.conf'), 'w') do |f|
      f.puts("environment=bar")
    end

    Puppet.initialize_settings(['--environment', 'baz'])
    cat = compile_to_catalog('notify { $::agent_specified_environment: }',
                             Puppet::Node.indirection.find('foo'))
    expect(cat.resource("Notify[baz]")).to be
  end
end
