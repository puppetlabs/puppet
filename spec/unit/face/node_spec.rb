#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:node, '0.0.1'] do
  describe '#cleanup' do
    it "should clean everything" do
      {
        "cert"         => ['hostname'],
        "cached_facts" => ['hostname'],
        "cached_node"  => ['hostname'],
        "reports"      => ['hostname'],

        # Support for cleaning storeconfigs has been temporarily suspended.
        # "storeconfigs" => ['hostname', :unexport]
      }.each { |k, v| subject.expects("clean_#{k}".to_sym).with(*v) }
      subject.cleanup('hostname', :unexport)
    end
  end

  describe 'when running #clean' do
    before :each do
      Puppet::Node::Facts.indirection.stubs(:terminus_class=)
      Puppet::Node::Facts.indirection.stubs(:cache_class=)
      Puppet::Node.stubs(:terminus_class=)
      Puppet::Node.stubs(:cache_class=)
    end

    it 'should invoke #cleanup' do
      subject.expects(:cleanup).with('hostname', nil)
      subject.clean('hostname')
    end
  end

  describe "clean action" do
    before :each do
      Puppet::Node::Facts.indirection.stubs(:terminus_class=)
      Puppet::Node::Facts.indirection.stubs(:cache_class=)
      Puppet::Node.stubs(:terminus_class=)
      Puppet::Node.stubs(:cache_class=)
      subject.stubs(:cleanup)
    end

    it "should have a clean action" do
      subject.should be_action :clean
    end

    it "should not accept a call with no arguments" do
      expect { subject.clean() }.should raise_error
    end

    it "should accept a node name" do
      expect { subject.clean('hostname') }.should_not raise_error
    end

    it "should accept more than one node name" do
      expect do
        subject.clean('hostname', 'hostname2', {})
      end.should_not raise_error

      expect do
        subject.clean('hostname', 'hostname2', 'hostname3', { :unexport => true })
      end.should_not raise_error
    end

    it "should accept the option --unexport" do
      expect { subject.help('hostname', :unexport => true) }.
        should_not raise_error ArgumentError
    end

    context "clean action" do
      subject { Puppet::Face[:node, :current] }
      before :each do
        Puppet::Util::Log.stubs(:newdestination)
        Puppet::Util::Log.stubs(:level=)
      end

      describe "during setup" do
        it "should set facts terminus and cache class to yaml" do
          Puppet::Node::Facts.indirection.expects(:terminus_class=).with(:yaml)
          Puppet::Node::Facts.indirection.expects(:cache_class=).with(:yaml)

          subject.clean('hostname')
        end

        it "should run in master mode" do
          subject.clean('hostname')
          $puppet_application_mode.name.should == :master
        end

        it "should set node cache as yaml" do
          Puppet::Node.indirection.expects(:terminus_class=).with(:yaml)
          Puppet::Node.indirection.expects(:cache_class=).with(:yaml)

          subject.clean('hostname')
        end

        it "should manage the certs if the host is a CA" do
          Puppet::SSL::CertificateAuthority.stubs(:ca?).returns(true)
          Puppet::SSL::Host.expects(:ca_location=).with(:local)
          subject.clean('hostname')
        end

        it "should not manage the certs if the host is not a CA" do
          Puppet::SSL::CertificateAuthority.stubs(:ca?).returns(false)
          Puppet::SSL::Host.expects(:ca_location=).with(:none)
          subject.clean('hostname')
        end
      end

      describe "when cleaning certificate" do
        before :each do
          Puppet::SSL::Host.stubs(:destroy)
          @ca = mock()
          Puppet::SSL::CertificateAuthority.stubs(:instance).returns(@ca)
        end

        it "should send the :destroy order to the ca if we are a CA" do
          Puppet::SSL::CertificateAuthority.stubs(:ca?).returns(true)
          @ca.expects(:revoke).with(@host)
          @ca.expects(:destroy).with(@host)
          subject.clean_cert(@host)
        end

        it "should not destroy the certs if we are not a CA" do
          Puppet::SSL::CertificateAuthority.stubs(:ca?).returns(false)
          @ca.expects(:revoke).never
          @ca.expects(:destroy).never
          subject.clean_cert(@host)
        end
      end

      describe "when cleaning cached facts" do
        it "should destroy facts" do
          @host = 'node'
          Puppet::Node::Facts.indirection.expects(:destroy).with(@host)

          subject.clean_cached_facts(@host)
        end
      end

      describe "when cleaning cached node" do
        it "should destroy the cached node" do
          Puppet::Node::Yaml.any_instance.expects(:destroy)
          subject.clean_cached_node(@host)
        end
      end

      describe "when cleaning archived reports" do
        it "should tell the reports to remove themselves" do
          Puppet::Transaction::Report.indirection.stubs(:destroy).with(@host)

          subject.clean_reports(@host)
        end
      end

      # describe "when cleaning storeconfigs entries for host", :if => Puppet.features.rails? do
      #   before :each do
      #     # Stub this so we don't need access to the DB
      #     require 'puppet/rails/host'
      #
      #     Puppet.stubs(:[]).with(:storeconfigs).returns(true)
      #
      #     Puppet::Rails.stubs(:connect)
      #     @rails_node = stub_everything 'rails_node'
      #     Puppet::Rails::Host.stubs(:find_by_name).returns(@rails_node)
      #   end
      #
      #   it "should connect to the database" do
      #     Puppet::Rails.expects(:connect)
      #     subject.clean_storeconfigs(@host, false)
      #   end
      #
      #   it "should find the right host entry" do
      #     Puppet::Rails::Host.expects(:find_by_name).with(@host).returns(@rails_node)
      #     subject.clean_storeconfigs(@host, false)
      #   end
      #
      #   describe "without unexport" do
      #     it "should remove the host and it's content" do
      #       @rails_node.expects(:destroy)
      #       subject.clean_storeconfigs(@host, false)
      #     end
      #   end
      #
      #   describe "with unexport" do
      #     before :each do
      #       @rails_node.stubs(:id).returns(1234)
      #
      #       @type = stub_everything 'type'
      #       @type.stubs(:validattr?).with(:ensure).returns(true)
      #
      #       @ensure_name = stub_everything 'ensure_name', :id => 23453
      #       Puppet::Rails::ParamName.stubs(:find_or_create_by_name).returns(@ensure_name)
      #
      #       @param_values = stub_everything 'param_values'
      #       @resource = stub_everything 'resource', :param_values => @param_values, :restype => "File"
      #       Puppet::Rails::Resource.stubs(:find).returns([@resource])
      #     end
      #
      #     it "should find all resources" do
      #       Puppet::Rails::Resource.expects(:find).with(:all, {:include => {:param_values => :param_name}, :conditions => ["exported=? AND host_id=?", true, 1234]}).returns([])
      #
      #       subject.clean_storeconfigs(@host, true)
      #     end
      #
      #     describe "with an exported native type" do
      #       before :each do
      #         Puppet::Type.stubs(:type).returns(@type)
      #         @type.expects(:validattr?).with(:ensure).returns(true)
      #       end
      #
      #       it "should test a native type for ensure as an attribute" do
      #         subject.clean_storeconfigs(@host, true)
      #       end
      #
      #       it "should delete the old ensure parameter" do
      #         ensure_param = stub 'ensure_param', :id => 12345, :line => 12
      #         @param_values.stubs(:find).returns(ensure_param)
      #         Puppet::Rails::ParamValue.expects(:delete).with(12345);
      #         subject.clean_storeconfigs(@host, true)
      #       end
      #
      #       it "should add an ensure => absent parameter" do
      #         @param_values.expects(:create).with(:value => "absent",
      #                                             :line => 0,
      #                                             :param_name => @ensure_name)
      #         subject.clean_storeconfigs(@host, true)
      #       end
      #     end
      #
      #     describe "with an exported definition" do
      #       it "should try to lookup a definition and test it for the ensure argument" do
      #         Puppet::Type.stubs(:type).returns(nil)
      #         definition = stub_everything 'definition', :arguments => { 'ensure' => 'present' }
      #         Puppet::Resource::TypeCollection.any_instance.expects(:find_definition).with('', "File").returns(definition)
      #         subject.clean_storeconfigs(@host, true)
      #       end
      #     end
      #
      #     it "should not unexport the resource of an unknown type" do
      #       Puppet::Type.stubs(:type).returns(nil)
      #       Puppet::Resource::TypeCollection.any_instance.expects(:find_definition).with('', "File").returns(nil)
      #       Puppet::Rails::ParamName.expects(:find_or_create_by_name).never
      #       subject.clean_storeconfigs(@host)
      #     end
      #
      #     it "should not unexport the resource of a not ensurable native type" do
      #       Puppet::Type.stubs(:type).returns(@type)
      #       @type.expects(:validattr?).with(:ensure).returns(false)
      #       Puppet::Resource::TypeCollection.any_instance.expects(:find_definition).with('', "File").returns(nil)
      #       Puppet::Rails::ParamName.expects(:find_or_create_by_name).never
      #       subject.clean_storeconfigs(@host, true)
      #     end
      #
      #     it "should not unexport the resource of a not ensurable definition" do
      #       Puppet::Type.stubs(:type).returns(nil)
      #       definition = stub_everything 'definition', :arguments => { 'foobar' => 'someValue' }
      #       Puppet::Resource::TypeCollection.any_instance.expects(:find_definition).with('', "File").returns(definition)
      #       Puppet::Rails::ParamName.expects(:find_or_create_by_name).never
      #       subject.clean_storeconfigs(@host, true)
      #     end
      #   end
      # end
    end
  end
end
