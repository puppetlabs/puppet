require 'spec_helper'
require 'puppet/module_tool'

describe Puppet::ModuleTool::Metadata do
  context "when using default values" do
    it "should set license to 'Apache License, Version 2.0'" do
      metadata = Puppet::ModuleTool::Metadata.new
      metadata.license.should == "Apache License, Version 2.0"
    end
  end
end
