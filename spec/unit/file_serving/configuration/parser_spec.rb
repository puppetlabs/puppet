require 'spec_helper'

require 'puppet/file_serving/configuration/parser'


module FSConfigurationParserTesting
  def write_config_file(content)
    # We want an array, but we actually want our carriage returns on all of it.
    File.open(@path, 'w') {|f| f.puts content}
  end
end

describe Puppet::FileServing::Configuration::Parser do
  include PuppetSpec::Files

  before :each do
    @path = tmpfile('fileserving_config')
    FileUtils.touch(@path)
    @parser = Puppet::FileServing::Configuration::Parser.new(@path)
  end

  describe Puppet::FileServing::Configuration::Parser, " when parsing" do
    include FSConfigurationParserTesting

    it "should allow comments" do
      write_config_file("# this is a comment\n")
      expect { @parser.parse }.not_to raise_error
    end

    it "should allow blank lines" do
      write_config_file("\n")
      expect { @parser.parse }.not_to raise_error
    end

    it "should return a hash of the created mounts" do
      mount1 = double('one', :validate => true)
      mount2 = double('two', :validate => true)
      expect(Puppet::FileServing::Mount::File).to receive(:new).with("one").and_return(mount1)
      expect(Puppet::FileServing::Mount::File).to receive(:new).with("two").and_return(mount2)
      write_config_file "[one]\n[two]\n"

      result = @parser.parse
      expect(result["one"]).to equal(mount1)
      expect(result["two"]).to equal(mount2)
    end

    it "should only allow mount names that are alphanumeric plus dashes" do
      write_config_file "[a*b]\n"
      expect { @parser.parse }.to raise_error(ArgumentError)
    end

    it "should fail if the value for path/allow/deny starts with an equals sign" do
      write_config_file "[one]\npath = /testing"
      expect { @parser.parse }.to raise_error(ArgumentError)
    end

    it "should validate each created mount" do
      mount1 = double('one')
      expect(Puppet::FileServing::Mount::File).to receive(:new).with("one").and_return(mount1)
      write_config_file "[one]\n"

      expect(mount1).to receive(:validate)

      @parser.parse
    end

    it "should fail if any mount does not pass validation" do
      mount1 = double('one')
      expect(Puppet::FileServing::Mount::File).to receive(:new).with("one").and_return(mount1)
      write_config_file "[one]\n"

      expect(mount1).to receive(:validate).and_raise(RuntimeError)

      expect { @parser.parse }.to raise_error(RuntimeError)
    end

    it "should return comprehensible error message, if invalid line detected" do
      write_config_file "[one]\n\n\x01path /etc/puppetlabs/puppet/files\n\x01allow *\n"

      expect { @parser.parse }.to raise_error(ArgumentError, /Invalid entry at \(file: .*, line: 3\): .*/)
    end
  end

  describe Puppet::FileServing::Configuration::Parser, " when parsing mount attributes" do
    include FSConfigurationParserTesting

    before do
      @mount = double('testmount', :name => "one", :validate => true)
      expect(Puppet::FileServing::Mount::File).to receive(:new).with("one").and_return(@mount)
    end

    it "should set the mount path to the path attribute from that section" do
      write_config_file "[one]\npath /some/path\n"

      expect(@mount).to receive(:path=).with("/some/path")
      @parser.parse
    end

    [:allow,:deny].each { |acl_type|
      it "should support inline comments in #{acl_type}" do
        write_config_file "[one]\n#{acl_type} something \# will it work?\n"

      expect(@mount).to receive(:info)
      expect(@mount).to receive(acl_type).with("something")
      @parser.parse
      end

      it "should tell the mount to #{acl_type} from ACLs with varying spacing around commas" do
        write_config_file "[one]\n#{acl_type} someone,sometwo, somethree , somefour ,somefive\n"

        expect(@mount).to receive(:info).exactly(5).times
        expect(@mount).to receive(acl_type).exactly(5).times.with(eq('someone').or eq('sometwo').or eq('somethree').or eq('somefour').or eq('somefive'))
        @parser.parse
      end

      # each ip, with glob in the various octet positions
      ['100','4','42','*'].permutation.map {|permutes| permutes.join('.') }.each { |ip_pattern|
        it "should tell the mount to #{acl_type} from ACLs with glob at #{ip_pattern}" do
          write_config_file "[one]\n#{acl_type} #{ip_pattern}\n"

          expect(@mount).to receive(:info)
          expect(@mount).to receive(acl_type).with(ip_pattern)
          @parser.parse
        end
      }
    }

    it "should return comprehensible error message, if failed on invalid attribute" do
      write_config_file "[one]\ndo something\n"

      expect { @parser.parse }.to raise_error(ArgumentError, /Invalid argument 'do' at \(file: .*, line: 2\)/)
    end
  end

  describe Puppet::FileServing::Configuration::Parser, " when parsing the modules mount" do
    include FSConfigurationParserTesting

    before do
      @mount = double('modulesmount', :name => "modules", :validate => true)
    end

    it "should create an instance of the Modules Mount class" do
      write_config_file "[modules]\n"

      expect(Puppet::FileServing::Mount::Modules).to receive(:new).with("modules").and_return(@mount)
      @parser.parse
    end

    it "should warn if a path is set" do
      write_config_file "[modules]\npath /some/path\n"
      expect(Puppet::FileServing::Mount::Modules).to receive(:new).with("modules").and_return(@mount)

      expect(Puppet).to receive(:warning)
      @parser.parse
    end
  end

  describe Puppet::FileServing::Configuration::Parser, " when parsing the scripts mount" do
    include FSConfigurationParserTesting

    before do
      @mount = double('scriptsmount', :name => "scripts", :validate => true)
    end

    it "should create an instance of the Scripts Mount class" do
      write_config_file "[scripts]\n"

      expect(Puppet::FileServing::Mount::Scripts).to receive(:new).with("scripts").and_return(@mount)
      @parser.parse
    end

    it "should warn if a path is set" do
      write_config_file "[scripts]\npath /some/path\n"
      expect(Puppet::FileServing::Mount::Scripts).to receive(:new).with("scripts").and_return(@mount)

      expect(Puppet).to receive(:warning)
      @parser.parse
    end
  end

  describe Puppet::FileServing::Configuration::Parser, " when parsing the plugins mount" do
    include FSConfigurationParserTesting

    before do
      @mount = double('pluginsmount', :name => "plugins", :validate => true)
    end

    it "should create an instance of the Plugins Mount class" do
      write_config_file "[plugins]\n"

      expect(Puppet::FileServing::Mount::Plugins).to receive(:new).with("plugins").and_return(@mount)
      @parser.parse
    end

    it "should warn if a path is set" do
      write_config_file "[plugins]\npath /some/path\n"

      expect(Puppet).to receive(:warning)
      @parser.parse
    end
  end
end
