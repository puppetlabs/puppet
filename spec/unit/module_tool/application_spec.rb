require 'spec_helper'
require 'puppet/module_tool'

describe Puppet::ModuleTool::Applications::Application do
  describe 'app' do

    good_versions = %w{ 1.2.4 0.0.1 0.0.0 0.0.2-git-8-g3d316d1 0.0.3-b1 10.100.10000
                         0.1.2-rc1 0.1.2-dev-1 0.1.2-svn12345 0.1.2-3 }
    bad_versions = %w{ 0.1 0 0.1.2.3 dev 0.1.2beta }

    let :app do Class.new(described_class).new end

    good_versions.each do |ver|
      it "should accept version string #{ver}" do
        app.parse_filename("puppetlabs-ntp-#{ver}")
      end
    end

    bad_versions.each do |ver|
      it "should not accept version string #{ver}" do
        expect { app.parse_filename("puppetlabs-ntp-#{ver}") }.to raise_error(ArgumentError, /(Invalid version format|Could not parse filename)/)
      end
    end
  end
end
