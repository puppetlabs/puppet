require 'spec_helper'
require 'puppet/module_tool'

describe Puppet::ModuleTool::Metadata do
  context "when using default values" do
    it "should set license to 'Apache License, Version 2.0'" do
      metadata = Puppet::ModuleTool::Metadata.new
      metadata.license.should == "Apache License, Version 2.0"
    end
  end

  describe :to_hash do
    it 'should merge extra_data in' do
      metadata = Puppet::ModuleTool::Metadata.new
      metadata.extra_metadata = {
        'checksums' => 'badsums',
        'special_key' => 'special'
      }
      meta_hash = metadata.to_hash
      meta_hash['special_key'].should == 'special'
      meta_hash['checksums'].should == {}
    end
  end
end
