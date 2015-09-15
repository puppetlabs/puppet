require 'spec_helper'
require 'puppet/application/lookup'
require 'puppet/pops/lookup'

describe Puppet::Application::Lookup do

  context "when running with incorrect command line options" do
    let (:lookup) { Puppet::Application[:lookup] }

    it "errors if no keys are given via the command line" do
      lookup.options[:node] = 'dantooine.local'
      expected_error = "No keys were given to lookup."

      expect{ lookup.run_command }.to raise_error(RuntimeError, expected_error)
    end

    it "errors if no node was given via the --node flag" do
      lookup.command_line.stubs(:args).returns(['atton', 'kreia'])

      expected_error = "No node was given via the '--node' flag for the scope of the lookup."

      expect{ lookup.run_command }.to raise_error(RuntimeError, expected_error)
    end

    it "does not allow deep merge options if '--merge' was not set to deep" do
      lookup.options[:node] = 'dantooine.local'
      lookup.options[:merge_hash_arrays] = true
      lookup.options[:merge] = 'hash'
      lookup.command_line.stubs(:args).returns(['atton', 'kreia'])

      expected_error = "The options --knock-out-prefix, --sort-merged-arrays, --unpack-arrays, and --merge-hash-arrays are only available with '--merge deep'\nRun 'puppet lookup --help' for more details"

      expect{ lookup.run_command }.to raise_error(RuntimeError, expected_error)
    end
  end

  context "when running with correct command line options" do
    let (:lookup) { Puppet::Application[:lookup] }

    it "prints the value found by lookup" do
      lookup.options[:node] = 'dantooine.local'
      lookup.command_line.stubs(:args).returns(['atton', 'kreia'])
      lookup.stubs(:generate_scope).returns('scope')

      Puppet::Pops::Lookup.stubs(:lookup).returns('rand')

      expect{ lookup.run_command }.to output("rand\n").to_stdout
    end
  end
end
