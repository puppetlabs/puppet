require 'spec_helper'
require 'puppet/module_tool/applications'

describe Puppet::Module::Tool::Applications do
  module Puppet::Module::Tool
    module Applications
      class Fake < Application
      end
    end
  end

  it "should raise an error on microsoft windows" do
    Puppet.features.stubs(:microsoft_windows?).returns true
    expect { Puppet::Module::Tool::Applications::Fake.new }.to raise_error(
      Puppet::Error,
      "`puppet module` actions are currently not supported on Microsoft Windows"
    )
  end
end
