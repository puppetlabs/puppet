require 'spec_helper'

describe Puppet.version do
  include PuppetSpec::Files

  let(:test_version) { "1.2.3" }
  let(:test_pe_version) { "3.4.5" }

  before do
    # Create a temp file to use for the pe version file
    # and write the desired version string out to it
    @pe_file = tmpfile('pe_version')
    pe_version_file = File.open(@pe_file, "w")
    pe_version_file.puts(test_pe_version)
    pe_version_file.close
    with_verbose_disabled { Puppet.const_set(:PEVersionFile, @pe_file) }
    with_verbose_disabled { Puppet.const_set(:PUPPETVERSION, test_version) }
  end

  it "Should return just the version if there is no pe_version file" do
    File.stubs(:readable?).with(@pe_file).returns(false)
    Puppet.version.should == test_version
  end

  it "Should return '$Version (Puppet Enterprise $PEVersion)' if there is a pe_version file" do
    Puppet.version.should == "#{test_version} (Puppet Enterprise #{test_pe_version})"
  end
end
