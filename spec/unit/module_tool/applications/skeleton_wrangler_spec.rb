require 'spec_helper'
require 'puppet/module_tool/applications'

describe Puppet::ModuleTool::Applications::SkeletonWrangler do
  let(:skeleton_wrangler) { Puppet::ModuleTool::Applications::SkeletonWrangler.new() }

  it "should attempt to display skeleton path settings" do

    Puppet.expects(:notice).with("Fetching your skeletons...")

    skeleton_wrangler.run.should include "Default Path", "Custom Path"
  end
  
end
