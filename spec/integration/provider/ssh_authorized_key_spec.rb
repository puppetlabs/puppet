#! /usr/bin/env ruby

require 'spec_helper'
require 'puppet/file_bucket/dipper'

describe Puppet::Type.type(:ssh_authorized_key).provider(:parsed), '(integration)', :unless => Puppet.features.microsoft_windows? do
  include PuppetSpec::Files

  let :fake_userfile do
    tmpfile('authorized_keys.user')
  end

  let :fake_rootfile do
    tmpfile('authorized_keys.root')
  end

  let :sample_rsa_keys do
    [
      'AAAAB3NzaC1yc2EAAAADAQABAAAAgQCi18JBZOq10X3w4f67nVhO0O3s5Y1vHH4UgMSM3ZnQwbC5hjGyYSi9UULOoQQoQynI/a0I9NL423/Xk/XJVIKCHcS8q6V2Wmjd+fLNelOjxxoW6mbIytEt9rDvwgq3Mof3/m21L3t2byvegR00a+ikKbmInPmKwjeWZpexCIsHzQ==', # 1024 bit
      'AAAAB3NzaC1yc2EAAAADAQABAAAAgQDLClyvi3CsJw5Id6khZs2/+s11qOH4Gdp6iDioDsrIp0m8kSiPr71VGyQYAfPzzvHemHS7Xg0NkG1Kc8u9tRqBQfTvz7ubq0AT/g01+4P2hQ/soFkuwlUG/HVnnaYb6N0Qp5SHWvD5vBE2nFFQVpP5GrSctPtHSjzJq/i+6LYhmQ==', # 1024 bit
      'AAAAB3NzaC1yc2EAAAADAQABAAABAQDLygAO6txXkh9FNV8xSsBkATeqLbHzS7sFjGI3gt0Dx6q3LjyKwbhQ1RLf28kd5G6VWiXmClU/RtiPdUz8nrGuun++2mrxzrXrvpR9dq1lygLQ2wn2cI35dN5bjRMtXy3decs6HUhFo9MoNwX250rUWfdCyNPhGIp6OOfmjdy+UeLGNxq9wDx6i4bT5tVVSqVRtsEfw9+ICXchzl85QudjneVVpP+thriPZXfXA5eaGwAo/dmoKOIhUwF96gpdLqzNtrGQuxPbV80PTbGv9ZtAtTictxaDz8muXO7he9pXmchUpxUKtMFjHkL0FAZ9tRPmv3RA30sEr2fZ8+LKvnE50w0' #2048 Bit
    ]
  end

  let :sample_dsa_keys do
    [
      'AAAAB3NzaC1kc3MAAACBAOPck2O8MIDSqxPSnvENt6tzRrKJ5oOhB6Nc6oEcWm+VEH1gvuxdiRqwoMgRwyEf1yUd+UAcLw3a6Jn+EtFyEBN/5WF+4Tt4xTxZ0Pfik2Wc5uqHbQ2dkmOoXiAOYPiD3JUQ1Xwm/J0CgetjitoLfzAGdCNhMqguqAuHcVJ78ZZbAAAAFQCIBKFYZ+I18I+dtgteirXh+VVEEwAAAIEAs1yvQ/wnLLrRCM660pF4kBiw3D6dJfMdCXWQpn0hZmkBQSIzZv4Wuk3giei5luxscDxNc+y3CTXtnyG4Kt1Yi2sOdvhRI3rX8tD+ejn8GHazM05l5VIo9uu4AQPIE32iV63IqgApSBbJ6vDJW91oDH0J492WdLCar4BS/KE3cRwAAACBAN0uSDyJqYLRsfYcFn4HyVf6TJxQm1IcwEt6GcJVzgjri9VtW7FqY5iBqa9B9Zdh5XXAYJ0XLsWQCcrmMHM2XGHGpA4gL9VlCJ/0QvOcXxD2uK7IXwAVUA7g4V4bw8EVnFv2Flufozhsp+4soo1xiYc5jiFVHwVlk21sMhAtKAeF' # 1024 Bit
    ]
  end

  let :sample_lines do
    [
      "ssh-rsa #{sample_rsa_keys[1]} root@someotherhost",
      "ssh-dss #{sample_dsa_keys[0]} root@anywhere",
      "ssh-rsa #{sample_rsa_keys[2]} paul",
      "ssh-rsa #{sample_rsa_keys[2]} dummy"
    ]
  end

  let :dummy do
    Puppet::Type.type(:ssh_authorized_key).new(
      :name   => 'dummy',
      :target => fake_userfile,
      :user   => 'nobody',
      :ensure => :absent
    )
  end

  before :each do
    File.stubs(:chown)
    File.stubs(:chmod)
    Puppet::Util::SUIDManager.stubs(:asuser).yields
  end

  after :each do
    described_class.clear # Work around bug #6628
  end

  def create_fake_key(username, content)
    filename = (username == :root ? fake_rootfile : fake_userfile )
    File.open(filename, 'w') do |f|
      content.each do |line|
        f.puts line
      end
    end
  end

  def check_fake_key(username, expected_content)
    filename = (username == :root ? fake_rootfile : fake_userfile )
    content = File.readlines(filename).map(&:chomp).sort.reject{ |x| x =~ /^# HEADER:/ }
    expect(content.join("\n")).to eq(expected_content.sort.join("\n"))
  end

  def run_in_catalog(*resources)
    Puppet::FileBucket::Dipper.any_instance.stubs(:backup) # Don't backup to the filebucket
    catalog = Puppet::Resource::Catalog.new
    catalog.host_config = false
    resources.each do |resource|
      resource.expects(:err).never
      catalog.add_resource(resource)
    end
    catalog.apply
  end

  it "should not complain about empty lines and comments" do
    described_class.expects(:flush).never
    sample = ['',sample_lines[0],'   ',sample_lines[1],'# just a comment','#and another']
    create_fake_key(:user,sample)
    run_in_catalog(dummy)
    check_fake_key(:user, sample)
  end

  it "should keep empty lines and comments when modifying a file" do
    create_fake_key(:user, ['',sample_lines[0],'   ',sample_lines[3],'# just a comment','#and another'])
    run_in_catalog(dummy)
    check_fake_key(:user, ['',sample_lines[0],'   ','# just a comment','#and another'])
  end

  describe "when managing one resource" do

    describe "with ensure set to absent" do
      let :resource do
        Puppet::Type.type(:ssh_authorized_key).new(
          :name     => 'root@hostname',
          :type     => :rsa,
          :key      => sample_rsa_keys[0],
          :target   => fake_rootfile,
          :user     => 'root',
          :ensure   => :absent
        )
      end

      it "should not modify root's keyfile if resource is currently not present" do
        create_fake_key(:root, sample_lines)
        run_in_catalog(resource)
        check_fake_key(:root, sample_lines)
      end

      it "remove the key from root's keyfile if resource is currently present" do
        create_fake_key(:root, sample_lines + ["ssh-rsa #{sample_rsa_keys[0]} root@hostname"])
        run_in_catalog(resource)
        check_fake_key(:root, sample_lines)
      end
    end

    describe "when ensure is present" do
      let :resource do
        Puppet::Type.type(:ssh_authorized_key).new(
          :name     => 'root@hostname',
          :type     => :rsa,
          :key      => sample_rsa_keys[0],
          :target   => fake_rootfile,
          :user     => 'root',
          :ensure   => :present
        )
      end

      # just a dummy so the parsedfile provider is aware
      # of the user's authorized_keys file

      it "should add the key if it is not present" do
        create_fake_key(:root, sample_lines)
        run_in_catalog(resource)
        check_fake_key(:root, sample_lines + ["ssh-rsa #{sample_rsa_keys[0]} root@hostname" ])
      end

      it "should modify the type if type is out of sync" do
        create_fake_key(:root,sample_lines + [ "ssh-dss #{sample_rsa_keys[0]} root@hostname" ])
        run_in_catalog(resource)
        check_fake_key(:root, sample_lines + [ "ssh-rsa #{sample_rsa_keys[0]} root@hostname" ])
      end

      it "should modify the key if key is out of sync" do
        create_fake_key(:root,sample_lines + [ "ssh-rsa #{sample_rsa_keys[1]} root@hostname" ])
        run_in_catalog(resource)
        check_fake_key(:root, sample_lines + [ "ssh-rsa #{sample_rsa_keys[0]} root@hostname" ])
      end

      it "should remove the key from old file if target is out of sync" do
        create_fake_key(:user, [ sample_lines[0], "ssh-rsa #{sample_rsa_keys[0]} root@hostname" ])
        create_fake_key(:root, [ sample_lines[1], sample_lines[2] ])
        run_in_catalog(resource, dummy)
        check_fake_key(:user, [ sample_lines[0] ])
        #check_fake_key(:root, [ sample_lines[1], sample_lines[2], "ssh-rsa #{sample_rsa_keys[0]} root@hostname" ])
      end

      it "should add the key to new file if target is out of sync" do
        create_fake_key(:user, [ sample_lines[0], "ssh-rsa #{sample_rsa_keys[0]} root@hostname" ])
        create_fake_key(:root, [ sample_lines[1], sample_lines[2] ])
        run_in_catalog(resource, dummy)
        #check_fake_key(:user, [ sample_lines[0] ])
        check_fake_key(:root, [ sample_lines[1], sample_lines[2], "ssh-rsa #{sample_rsa_keys[0]} root@hostname" ])
      end

      it "should modify options if options are out of sync" do
        resource[:options]=[ 'from="*.domain1,host1.domain2"', 'no-port-forwarding', 'no-pty' ]
        create_fake_key(:root, sample_lines + [ "from=\"*.false,*.false2\",no-port-forwarding,no-pty ssh-rsa #{sample_rsa_keys[0]} root@hostname"])
        run_in_catalog(resource)
        check_fake_key(:root, sample_lines + [ "from=\"*.domain1,host1.domain2\",no-port-forwarding,no-pty ssh-rsa #{sample_rsa_keys[0]} root@hostname"] )
      end
    end
  end

  describe "when managing two resource" do
    let :examples do
      resources = []
      resources << Puppet::Type.type(:ssh_authorized_key).new(
        :name     => 'root@hostname',
        :type     => :rsa,
        :key      => sample_rsa_keys[0],
        :target   => fake_rootfile,
        :user     => 'root',
        :ensure   => :present
      )
      resources << Puppet::Type.type(:ssh_authorized_key).new(
        :name   => 'user@hostname',
        :key    => sample_rsa_keys[1],
        :type   => :rsa,
        :target => fake_userfile,
        :user   => 'nobody',
        :ensure => :present
      )
      resources
    end

    describe "and both keys are absent" do
      before :each do
        create_fake_key(:root, sample_lines)
        create_fake_key(:user, sample_lines)
      end

      it "should add both keys" do
        run_in_catalog(*examples)
        check_fake_key(:root, sample_lines + [ "ssh-rsa #{sample_rsa_keys[0]} root@hostname" ])
        check_fake_key(:user, sample_lines + [ "ssh-rsa #{sample_rsa_keys[1]} user@hostname" ])
      end
    end
  end
end
