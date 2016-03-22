#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:package) do

  before do
    Puppet::Util::Storage.stubs(:store)
  end

  it "should have a :package_settings feature that requires :package_settings_insync?, :package_settings and :package_settings=" do
    described_class.provider_feature(:package_settings).methods.should == [:package_settings_insync?, :package_settings, :package_settings=]
  end

  context "when validating attributes" do
    it "should have a package_settings property" do
      described_class.attrtype(:package_settings).should == :property
    end
  end

  context "when validating attribute values" do
    let(:provider) do
      stub( 'provider',
            :class => described_class.defaultprovider,
            :clear => nil,
            :validate_source => false )
    end
    before do
      provider.class.stubs(:supports_parameter?).returns(true)
      described_class.defaultprovider.stubs(:new).returns(provider)
    end
    describe 'package_settings' do
      context "with a minimalistic provider supporting package_settings" do
        context "and {:package_settings => :settings}" do
          let(:resource) do 
            described_class.new :name => 'foo', :package_settings => :settings
          end
          it { expect { resource }.to_not raise_error }
          it "should set package_settings to :settings" do
            resource.value(:package_settings).should be :settings
          end
        end
      end
      context "with a provider that supports validation of the package_settings" do
        context "and {:package_settings => :valid_value}" do
          before do
            provider.expects(:package_settings_validate).once.with(:valid_value).returns(true)
          end
          let(:resource) do 
            described_class.new :name => 'foo', :package_settings => :valid_value
          end
          it { expect { resource }.to_not raise_error }
          it "should set package_settings to :valid_value" do
            resource.value(:package_settings).should == :valid_value
          end
        end
        context "and {:package_settings => :invalid_value}" do
          before do
            msg = "package_settings must be a Hash, not Symbol"
            provider.expects(:package_settings_validate).once.
              with(:invalid_value).raises(ArgumentError, msg)
          end
          let(:resource) do 
            described_class.new :name => 'foo', :package_settings => :invalid_value
          end
          it do
            expect { resource }.to raise_error Puppet::Error,
              /package_settings must be a Hash, not Symbol/
          end
        end
      end
      context "with a provider that supports munging of the package_settings" do
        context "and {:package_settings => 'A'}" do
          before do
            provider.expects(:package_settings_munge).once.with('A').returns(:a)
          end
          let(:resource) do 
            described_class.new :name => 'foo', :package_settings => 'A'
          end
          it do
            expect { resource }.to_not raise_error 
          end
          it "should set package_settings to :a" do
            resource.value(:package_settings).should be :a
          end
        end
      end
    end
  end
  describe "package_settings property" do
    let(:provider) do
      stub( 'provider',
            :class => described_class.defaultprovider,
            :clear => nil,
            :validate_source => false )
    end
    before do
      provider.class.stubs(:supports_parameter?).returns(true)
      described_class.defaultprovider.stubs(:new).returns(provider)
    end
    context "with {package_settings => :should}" do
      let(:resource) do 
        described_class.new :name => 'foo', :package_settings => :should
      end
      describe "#insync?(:is)" do
        it "returns the result of provider.package_settings_insync?(:should,:is)" do
          resource.provider.expects(:package_settings_insync?).once.with(:should,:is).returns :ok1
          resource.property(:package_settings).insync?(:is).should be :ok1
        end
      end
      describe "#should_to_s(:newvalue)" do
        it "returns the result of provider.package_settings_should_to_s(:should,:newvalue)" do
          resource.provider.expects(:package_settings_should_to_s).once.with(:should,:newvalue).returns :ok2
          resource.property(:package_settings).should_to_s(:newvalue).should be :ok2
        end
      end
      describe "#is_to_s(:currentvalue)" do
        it "returns the result of provider.package_settings_is_to_s(:should,:currentvalue)" do
          resource.provider.expects(:package_settings_is_to_s).once.with(:should,:currentvalue).returns :ok3
          resource.property(:package_settings).is_to_s(:currentvalue).should be :ok3
        end
      end
    end
    context "with any non-nil package_settings" do
      describe "#change_to_s(:currentvalue,:newvalue)" do
        let(:resource) do 
          described_class.new :name => 'foo', :package_settings => {}
        end
        it "returns the result of provider.package_settings_change_to_s(:currentvalue,:newvalue)" do
          resource.provider.expects(:package_settings_change_to_s).once.with(:currentvalue,:newvalue).returns :ok4
          resource.property(:package_settings).change_to_s(:currentvalue,:newvalue).should be :ok4
        end
      end
    end
  end
end
