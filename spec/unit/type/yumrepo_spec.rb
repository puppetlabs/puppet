require 'spec_helper'
require 'puppet'

shared_examples_for "a yumrepo parameter that can be absent" do |param|
  it "can be set as :absent" do
    described_class.new(:name => 'puppetlabs', param => :absent)
  end
  it "can be set as \"absent\"" do
    described_class.new(:name => 'puppetlabs', param => 'absent')
  end
end

shared_examples_for "a yumrepo parameter that can be an integer" do |param|
  it "accepts a valid positive integer" do
    instance = described_class.new(:name => 'puppetlabs', param => '12')
    expect(instance[param]).to eq '12'
  end
  it "accepts zero" do
    instance = described_class.new(:name => 'puppetlabs', param => '0')
    expect(instance[param]).to eq '0'
  end
  it "rejects invalid positive float" do
    expect {
      described_class.new(
        :name => 'puppetlabs',
        param => '12.5'
      )
    }.to raise_error(Puppet::ResourceError, /Parameter #{param} failed/)
  end
  it "rejects invalid non-integer" do
    expect {
      described_class.new(
        :name => 'puppetlabs',
        param => 'I\'m a six'
      )
    }.to raise_error(Puppet::ResourceError, /Parameter #{param} failed/)
  end
  it "rejects invalid string with integers inside" do
    expect {
      described_class.new(
        :name => 'puppetlabs',
        param => 'I\'m a 6'
      )
    }.to raise_error(Puppet::ResourceError, /Parameter #{param} failed/)
  end
end

shared_examples_for "a yumrepo parameter that can't be a negative integer" do |param|
  it "rejects invalid negative integer" do
    expect {
      described_class.new(
          :name => 'puppetlabs',
          param => '-12'
      )
    }.to raise_error(Puppet::ResourceError, /Parameter #{param} failed/)
  end
end

shared_examples_for "a yumrepo parameter that expects a boolean parameter" do |param|
  valid_values = %w[true false 0 1 no yes]

  valid_values.each do |value|
    it "accepts #{value} downcased to #{value.downcase} and capitalizes it" do
      instance = described_class.new(:name => 'puppetlabs', param => value.downcase)
      expect(instance[param]).to eq value.downcase.capitalize
    end
    it "fails on valid value #{value} contained in another value" do
        expect {
          described_class.new(
            :name => 'puppetlabs',
            param => "bla#{value}bla"
          )
        }.to raise_error(Puppet::ResourceError, /Parameter #{param} failed/)
    end
  end

  it "rejects invalid boolean values" do
    expect {
      described_class.new(:name => 'puppetlabs', param => 'flase')
    }.to raise_error(Puppet::ResourceError, /Parameter #{param} failed/)
  end
end

shared_examples_for "a yumrepo parameter that accepts a single URL" do |param|
  it "can accept a single URL" do
    described_class.new(
      :name => 'puppetlabs',
      param => 'http://localhost/yumrepos'
    )
  end

  it "fails if an invalid URL is provided" do
    expect {
      described_class.new(
        :name => 'puppetlabs',
        param => "that's no URL!"
      )
    }.to raise_error(Puppet::ResourceError, /Parameter #{param} failed/)
  end

  it "fails if a valid URL uses an invalid URI scheme" do
    expect {
      described_class.new(
        :name => 'puppetlabs',
        param => 'ldap://localhost/yumrepos'
      )
    }.to raise_error(Puppet::ResourceError, /Parameter #{param} failed/)
  end
end

shared_examples_for "a yumrepo parameter that accepts multiple URLs" do |param|
  it "can accept multiple URLs" do
    described_class.new(
      :name => 'puppetlabs',
      param => 'http://localhost/yumrepos http://localhost/more-yumrepos'
    )
  end

  it "fails if multiple URLs are given and one is invalid" do
    expect {
      described_class.new(
        :name => 'puppetlabs',
        param => "http://localhost/yumrepos That's no URL!"
      )
    }.to raise_error(Puppet::ResourceError, /Parameter #{param} failed/)
  end
end

shared_examples_for "a yumrepo parameter that accepts kMG units" do |param|
  %w[k M G].each do |unit|
    it "can accept an integer with #{unit} units" do
      described_class.new(
        :name => 'puppetlabs',
        param => "123#{unit}"
      )
    end
  end

  it "fails if wrong unit passed" do
    expect {
      described_class.new(
        :name => 'puppetlabs',
        param => '123J'
      )
    }.to raise_error(Puppet::ResourceError, /Parameter #{param} failed/)
  end
end

describe Puppet::Type.type(:yumrepo) do
  it "has :name as its namevar" do
    expect(described_class.key_attributes).to eq [:name]
  end

  describe "validating" do

    describe "name" do
      it "is a valid parameter" do
        instance = described_class.new(:name => 'puppetlabs')
        expect(instance.name).to eq 'puppetlabs'
      end
    end

    describe "target" do
      it_behaves_like "a yumrepo parameter that can be absent", :target
    end

    describe "descr" do
      it_behaves_like "a yumrepo parameter that can be absent", :descr
    end

    describe "mirrorlist" do
      it_behaves_like "a yumrepo parameter that accepts a single URL", :mirrorlist
      it_behaves_like "a yumrepo parameter that can be absent", :mirrorlist
    end

    describe "baseurl" do
      it_behaves_like "a yumrepo parameter that can be absent", :baseurl
      it_behaves_like "a yumrepo parameter that accepts a single URL", :baseurl
      it_behaves_like "a yumrepo parameter that accepts multiple URLs", :baseurl
    end

    describe "enabled" do
      it_behaves_like "a yumrepo parameter that expects a boolean parameter", :enabled
      it_behaves_like "a yumrepo parameter that can be absent", :enabled
    end

    describe "gpgcheck" do
      it_behaves_like "a yumrepo parameter that expects a boolean parameter", :gpgcheck
      it_behaves_like "a yumrepo parameter that can be absent", :gpgcheck
    end

    describe "payload_gpgcheck" do
      it_behaves_like "a yumrepo parameter that expects a boolean parameter", :payload_gpgcheck
      it_behaves_like "a yumrepo parameter that can be absent", :payload_gpgcheck
    end

    describe "repo_gpgcheck" do
      it_behaves_like "a yumrepo parameter that expects a boolean parameter", :repo_gpgcheck
      it_behaves_like "a yumrepo parameter that can be absent", :repo_gpgcheck
    end

    describe "gpgkey" do
      it_behaves_like "a yumrepo parameter that can be absent", :gpgkey
      it_behaves_like "a yumrepo parameter that accepts a single URL", :gpgkey
      it_behaves_like "a yumrepo parameter that accepts multiple URLs", :gpgkey
    end

    describe "include" do
      it_behaves_like "a yumrepo parameter that can be absent", :include
      it_behaves_like "a yumrepo parameter that accepts a single URL", :include
    end

    describe "exclude" do
      it_behaves_like "a yumrepo parameter that can be absent", :exclude
    end

    describe "includepkgs" do
      it_behaves_like "a yumrepo parameter that can be absent", :includepkgs
    end

    describe "enablegroups" do
      it_behaves_like "a yumrepo parameter that expects a boolean parameter", :enablegroups
      it_behaves_like "a yumrepo parameter that can be absent", :enablegroups
    end

    describe "failovermethod" do

      %w[roundrobin priority].each do |value|
        it "accepts a value of #{value}" do
          described_class.new(:name => "puppetlabs", :failovermethod => value)
        end
        it "fails on valid value #{value} contained in another value" do
          expect {
            described_class.new(
              :name => 'puppetlabs',
              :failovermethod => "bla#{value}bla"
            )
          }.to raise_error(Puppet::ResourceError, /Parameter failovermethod failed/)
        end
      end

      it "raises an error if an invalid value is given" do
        expect {
          described_class.new(:name => "puppetlabs", :failovermethod => "notavalidvalue")
        }.to raise_error(Puppet::ResourceError, /Parameter failovermethod failed/)
      end

      it_behaves_like "a yumrepo parameter that can be absent", :failovermethod
    end

    describe "keepalive" do
      it_behaves_like "a yumrepo parameter that expects a boolean parameter", :keepalive
      it_behaves_like "a yumrepo parameter that can be absent", :keepalive
    end

    describe "http_caching" do
      %w[packages all none].each do |value|
        it "accepts a valid value of #{value}" do
          described_class.new(:name => 'puppetlabs', :http_caching => value)
        end
        it "fails on valid value #{value} contained in another value" do
          expect {
            described_class.new(
              :name => 'puppetlabs',
              :http_caching => "bla#{value}bla"
            )
          }.to raise_error(Puppet::ResourceError, /Parameter http_caching failed/)
        end
      end

      it "rejects invalid values" do
        expect {
          described_class.new(:name => 'puppetlabs', :http_caching => 'yes')
        }.to raise_error(Puppet::ResourceError, /Parameter http_caching failed/)
      end

      it_behaves_like "a yumrepo parameter that can be absent", :http_caching
    end

    describe "timeout" do
      it_behaves_like "a yumrepo parameter that can be absent", :timeout
      it_behaves_like "a yumrepo parameter that can be an integer", :timeout
      it_behaves_like "a yumrepo parameter that can't be a negative integer", :timeout
    end

    describe "metadata_expire" do
      it_behaves_like "a yumrepo parameter that can be absent", :metadata_expire
      it_behaves_like "a yumrepo parameter that can be an integer", :metadata_expire
      it_behaves_like "a yumrepo parameter that can't be a negative integer", :metadata_expire

      it "accepts dhm units" do
        %W[d h m].each do |unit|
          described_class.new(
            :name            => 'puppetlabs',
            :metadata_expire => "123#{unit}"
          )
        end
      end

      it "accepts never as value" do
        described_class.new(:name => 'puppetlabs', :metadata_expire => 'never')
      end
    end

    describe "protect" do
      it_behaves_like "a yumrepo parameter that expects a boolean parameter", :protect
      it_behaves_like "a yumrepo parameter that can be absent", :protect
    end

    describe "priority" do
      it_behaves_like "a yumrepo parameter that can be absent", :priority
      it_behaves_like "a yumrepo parameter that can be an integer", :priority
    end

    describe "proxy" do
      it_behaves_like "a yumrepo parameter that can be absent", :proxy
      it "accepts _none_" do
        described_class.new(
          :name  => 'puppetlabs',
          :proxy => "_none_"
        )
      end
      it_behaves_like "a yumrepo parameter that accepts a single URL", :proxy
    end

    describe "proxy_username" do
      it_behaves_like "a yumrepo parameter that can be absent", :proxy_username
    end

    describe "proxy_password" do
      it_behaves_like "a yumrepo parameter that can be absent", :proxy_password

      context "for password information in the logs" do
        let(:transaction) { Puppet::Transaction.new(Puppet::Resource::Catalog.new, nil, nil) }
        let(:harness) { Puppet::Transaction::ResourceHarness.new(transaction) }
        let(:provider_class) { described_class.provide(:simple) do
          mk_resource_methods
          def create; end
          def delete; end
          def exists?; get(:ensure) != :absent; end
          def flush; end
          def self.instances; []; end
        end
        }
        let(:provider) { provider_class.new(:name => 'foo', :ensure => :present) }
        let(:resource) { described_class.new(:name => 'puppetlabs', :proxy_password => 'top secret', :provider => provider) }

        it "redacts on creation" do
          status = harness.evaluate(resource)
          sync_event = status.events[0]
          expect(sync_event.message).to eq 'changed [redacted] to [redacted]'
        end

        it "redacts on update" do
          harness.evaluate(resource)
          resource[:proxy_password] = 'super classified'
          status = harness.evaluate(resource)
          sync_event = status.events[0]
          expect(sync_event.message).to eq 'changed [redacted] to [redacted]'
        end
      end
    end

    describe "s3_enabled" do
      it_behaves_like "a yumrepo parameter that expects a boolean parameter", :s3_enabled
      it_behaves_like "a yumrepo parameter that can be absent", :s3_enabled
    end

    describe "skip_if_unavailable" do
      it_behaves_like "a yumrepo parameter that expects a boolean parameter", :skip_if_unavailable
      it_behaves_like "a yumrepo parameter that can be absent", :skip_if_unavailable
    end

    describe "sslcacert" do
      it_behaves_like "a yumrepo parameter that can be absent", :sslcacert
    end

    describe "sslverify" do
      it_behaves_like "a yumrepo parameter that expects a boolean parameter", :sslverify
      it_behaves_like "a yumrepo parameter that can be absent", :sslverify
    end

    describe "sslclientcert" do
      it_behaves_like "a yumrepo parameter that can be absent", :sslclientcert
    end

    describe "sslclientkey" do
      it_behaves_like "a yumrepo parameter that can be absent", :sslclientkey
    end

    describe "metalink" do
      it_behaves_like "a yumrepo parameter that can be absent", :metalink
      it_behaves_like "a yumrepo parameter that accepts a single URL", :metalink
    end

    describe "assumeyes" do
      it_behaves_like "a yumrepo parameter that expects a boolean parameter", :assumeyes
      it_behaves_like "a yumrepo parameter that can be absent", :assumeyes
    end


    describe "cost" do
      it_behaves_like "a yumrepo parameter that can be absent", :cost
      it_behaves_like "a yumrepo parameter that can be an integer", :cost
      it_behaves_like "a yumrepo parameter that can't be a negative integer", :cost
    end

    describe "throttle" do
      it_behaves_like "a yumrepo parameter that can be absent", :throttle
      it_behaves_like "a yumrepo parameter that can be an integer", :throttle
      it_behaves_like "a yumrepo parameter that can't be a negative integer", :throttle
      it_behaves_like "a yumrepo parameter that accepts kMG units", :throttle

      it "accepts percentage as unit" do
        described_class.new(
          :name     => 'puppetlabs',
          :throttle => '123%'
        )
      end
    end

    describe "bandwidth" do
      it_behaves_like "a yumrepo parameter that can be absent", :bandwidth
      it_behaves_like "a yumrepo parameter that can be an integer", :bandwidth
      it_behaves_like "a yumrepo parameter that can't be a negative integer", :bandwidth
      it_behaves_like "a yumrepo parameter that accepts kMG units", :bandwidth
    end

    describe "gpgcakey" do
      it_behaves_like "a yumrepo parameter that can be absent", :gpgcakey
      it_behaves_like "a yumrepo parameter that accepts a single URL", :gpgcakey
    end

    describe "retries" do
      it_behaves_like "a yumrepo parameter that can be absent", :retries
      it_behaves_like "a yumrepo parameter that can be an integer", :retries
      it_behaves_like "a yumrepo parameter that can't be a negative integer", :retries
    end

    describe "mirrorlist_expire" do
      it_behaves_like "a yumrepo parameter that can be absent", :mirrorlist_expire
      it_behaves_like "a yumrepo parameter that can be an integer", :mirrorlist_expire
      it_behaves_like "a yumrepo parameter that can't be a negative integer", :mirrorlist_expire
    end

    describe "deltarpm_percentage" do
      it_behaves_like "a yumrepo parameter that can be absent", :deltarpm_percentage
      it_behaves_like "a yumrepo parameter that can be an integer", :deltarpm_percentage
      it_behaves_like "a yumrepo parameter that can't be a negative integer", :deltarpm_percentage
    end

    describe "deltarpm_metadata_percentage" do
      it_behaves_like "a yumrepo parameter that can be absent", :deltarpm_metadata_percentage
      it_behaves_like "a yumrepo parameter that can be an integer", :deltarpm_metadata_percentage
      it_behaves_like "a yumrepo parameter that can't be a negative integer", :deltarpm_metadata_percentage
    end

    describe "username" do
      it_behaves_like "a yumrepo parameter that can be absent", :username
    end

    describe "password" do
      it_behaves_like "a yumrepo parameter that can be absent", :password

      it "redacts password information from the logs" do
        resource = described_class.new(:name => 'puppetlabs', :password => 'top secret')
        harness = Puppet::Transaction::ResourceHarness.new(Puppet::Transaction.new(Puppet::Resource::Catalog.new, nil, nil))
        harness.evaluate(resource)
        resource[:password] = 'super classified'
        status = harness.evaluate(resource)
        sync_event = status.events[0]
        expect(sync_event.message).to eq 'changed [redacted] to [redacted]'
      end
    end
  end
end
