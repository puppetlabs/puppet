#!/usr/bin/env ruby

require 'spec_helper'

describe Puppet::Type.type(:project).provider(:projadd) do

  before do
    described_class.stubs(:suitable?).returns true
    Puppet::Type.type(:project).stubs(:defaultprovider).returns described_class
  end

  describe "when parsing testfiles" do
    it "should parse simple projects with empty fields" do
      described_class.expects(:projects).with('-l').returns File.read(my_fixture('simple'))
      described_class.expects(:new).with(
        :name       => 'min.project',
        :projid     => '0',
        :comment    => '',
        :users      => '',
        :groups     => '',
        :attributes => {},
        :ensure     => :present
      )
      described_class.expects(:new).with(
        :name       => 'max.project',
        :projid     => '2147483647',
        :comment    => '',
        :users      => '',
        :groups     => '',
        :attributes => {},
        :ensure     => :present
      )
      described_class.instances
    end

    it "should parse projects with one or more users" do
      described_class.expects(:projects).with('-l').returns File.read(my_fixture('user'))
      described_class.expects(:new).with(
        :name       => 'proj1',
        :projid     => '6900',
        :comment    => 'Single User',
        :users      => 'user1',
        :groups     => '',
        :attributes => {},
        :ensure     => :present
      )
      described_class.expects(:new).with(
        :name       => 'proj2',
        :projid     => '7000',
        :comment    => 'Multi User',
        :users      => 'user1,user2,user3',
        :groups     => '',
        :attributes => {},
        :ensure     => :present
      )
      described_class.instances
    end

    it "should parse projects with one or more groups" do
      described_class.expects(:projects).with('-l').returns File.read(my_fixture('groups'))
      described_class.expects(:new).with(
        :name       => 'proj1',
        :projid     => '6900',
        :comment    => 'Single group',
        :users      => '',
        :groups     => 'group',
        :attributes => {},
        :ensure     => :present
      )
      described_class.expects(:new).with(
        :name       => 'proj2',
        :projid     => '7000',
        :comment    => 'Multi group',
        :users      => '',
        :groups     => 'group1,group2,group3',
        :attributes => {},
        :ensure     => :present
      )
      described_class.instances
    end

    it "should parse projects with attributes" do
      described_class.expects(:projects).with('-l').returns File.read(my_fixture('attributes'))
      described_class.expects(:new).with(
        :name       => 'proj1',
        :projid     => '100',
        :comment    => 'Single Attrib',
        :users      => '',
        :groups     => '',
        :attributes => {:'process.max-sem-nsems' => '(priv,2048,deny)'},
        :ensure     => :present
      )
      described_class.expects(:new).with(
        :name       => 'proj2',
        :projid     => '6902',
        :comment    => 'Multiattrib',
        :users      => 'user1,user2',
        :groups     => 'group1,group2,group3',
        :attributes => {
          :'process.max-sem-nsems' => '(priv,2048,deny)',
          :'project.cpu-shares'    => nil,
          :'task.max-lwps'         => '(privileged,10,deny),(priv,1000,signal=KILL)',
        },
        :ensure     => :present
      )
      described_class.instances
    end

  end

  describe "when destroying a project" do

    it "should use the del command" do
      @provider = described_class.new(Puppet::Type.type(:project).new(:name => 'newproj',:comment => 'DestroyMe', :ensure => :absent))
      @provider.expects(:projdel).with('newproj')
      @provider.destroy
    end

  end

  describe "when creating a project" do

    it "should use the add command" do
      @provider = described_class.new(Puppet::Type.type(:project).new(:name => 'newproj'))
      @provider.expects(:projadd).with('newproj')
      @provider.create
    end

    it "should pass a comment with -c" do
      @provider = described_class.new(Puppet::Type.type(:project).new(:name => 'newproj', :comment => 'my comment'))
      @provider.expects(:projadd).with('-c','my comment','newproj')
      @provider.create
    end

    it "should pass projid with -p" do
      @provider = described_class.new(Puppet::Type.type(:project).new(:name => 'newproj', :projid => '1234'))
      @provider.expects(:projadd).with('-p','1234','newproj')
      @provider.create
    end

    it "should pass one user with -U" do
      @project = Puppet::Type.type(:project).new(:name => 'newproj', :users => 'one')
      @provider = described_class.new(@project)
      @provider.expects(:projadd).with('-U','one','newproj')
      @provider.create
    end

    it "should pass multiple users as comma separated list" do
      @project = Puppet::Type.type(:project).new(:name => 'newproj', :users => ['one','two'])
      @provider = described_class.new(@project)
      @provider.expects(:projadd).with('-U','one,two','newproj')
      @provider.create
    end

    it "should pass one group with -G" do
      @project = Puppet::Type.type(:project).new(:name => 'newproj', :groups => 'one')
      @provider = described_class.new(@project)
      @provider.expects(:projadd).with('-G','one','newproj')
      @provider.create
    end

    it "should pass multiple groups as comma separated list" do
      @project = Puppet::Type.type(:project).new(:name => 'newproj', :groups => ['one','two'])
      @provider = described_class.new(@project)
      @provider.expects(:projadd).with('-G','one,two','newproj')
      @provider.create
    end

    it "should pass attribute without value with -K key" do
      @project = Puppet::Type.type(:project).new(:name => 'newproj', :attributes => 'key')
      @provider = described_class.new(@project)
      @provider.expects(:projadd).with('-K','key','newproj')
      @provider.create
    end

    it "should pass multiple attributes with multiple -K" do
      @project = Puppet::Type.type(:project).new(:name => 'newproj', :attributes => ['key1=value1','key','key2=value2'])
      @provider = described_class.new(@project)

      # Because we convert attributes into a hash and then back, We cannot predict
      # the order of the arguments
      @provider.expects(:projadd).with() { |*arguments|
        arguments.size == 7
        arguments.pop.should == 'newproj'
        arguments[0].should == '-K'
        arguments[2].should == '-K'
        arguments[4].should == '-K'
        arguments.should include 'key1=value1'
        arguments.should include 'key'
        arguments.should include 'key2=value2'
      }
      @provider.create
    end

    it "should be able to pass attributes, where value has an equal sign in it" do
      @project = Puppet::Type.type(:project).new(:name => 'newproj', :attributes => ['key1=(subkey=value)'])
      @provider = described_class.new(@project)

      @provider.expects(:projadd).with('-K','key1=(subkey=value)','newproj')
      @provider.create
    end

  end

  describe "when modifying attributes" do

    before do
      @project = Puppet::Type.type(:project).new(
        :name   => 'proj1',
        :projid => '999',
        :users  => 'dont_care',
        :groups => 'dont_care'
      )
      @provider = described_class.new(@project)
    end

    it "should use -p to modify project id" do
      @provider.expects(:projmod).with('-p','100','proj1')
      @provider.projid=('100')
    end

    it "should use -c to modify comment" do
      @provider.expects(:projmod).with('-c','My Comment','proj1')
      @provider.comment=('My Comment')
    end

    it "should use -U to modify single user" do
      @provider.expects(:projmod).with('-U','user','proj1')
      @provider.users=('user')
    end

    it "should use comma separated list to modify multiple user" do
      @provider.expects(:projmod).with('-U','user1,user2','proj1')
      @provider.users=('user1,user2')
    end

    it "should use -r if we want to remove all existing users" do
      @provider.expects(:projmod).with('-r','-U','user1,user2','proj1')
      @provider.stubs(:get).with(:users).returns 'user1,user2'
      @provider.users=('')
    end

    it "should use -G to modify single group" do
      @provider.expects(:projmod).with('-G','group','proj1')
      @provider.groups=('group')
    end

    it "should use comma separated list to modify multiple groups" do
      @provider.expects(:projmod).with('-G','group1,group2','proj1')
      @provider.groups=('group1,group2')
    end

    it "should use -r if we want to remove all existing groups" do
      @provider.expects(:projmod).with('-r','-G','group1,group2','proj1')
      @provider.stubs(:get).with(:groups).returns 'group1,group2'
      @provider.groups=('')
    end

    it "should use -K and -s for substitute to modify single attribute" do
      @provider.expects(:projmod).with('-s','-K','key=value','proj1')
      @provider.attributes=({:key => 'value'})
    end

    it "should correctly set multiple attributes" do
      # Because we convert attributes into a hash and then back, we don't
      # know the order of the arguments
      # we expect projmod -s -K key1=value1 -K key2=value2 proj1
      # or        projmod -s -K key2=value2 -K key1=value1 proj1
      @provider.expects(:projmod).with { |*arguments|
        arguments.size == 6
        arguments.pop.should == 'proj1'
        arguments[0].should == '-s'
        arguments[1].should == '-K'
        arguments[3].should == '-K'
        arguments.should include 'key1=value1'
        arguments.should include 'key2=value2'
      }
      @provider.attributes=({:key1=>'value1',:key2=>'value2'})
    end

    it "should correctly set attributes with a key with no value" do
      @provider.expects(:projmod).with { |*arguments|
        arguments.size == 6
        arguments.pop.should == 'proj1'
        arguments[0].should == '-s'
        arguments[1].should == '-K'
        arguments[3].should == '-K'
        arguments.should include 'key99'
        arguments.should include 'key1=value1'
      }
      @provider.attributes=({:key1 => 'value1', :key99 => nil})
    end

    it "should correctly set attributes with a value with an equal sign" do
      @provider.expects(:projmod).with() { |*arguments|
        arguments.size == 6
        arguments.pop.should == 'proj1'
        arguments[0].should == '-s'
        arguments[1].should == '-K'
        arguments[3].should == '-K'
        arguments.should include 'key99=value99'
        arguments.should include 'key1=(subkey=value)'
      }
      @provider.attributes=({:key1 => '(subkey=value)', :key99 => 'value99'})
    end

    it "should delete existing attributes with -r if we dont want any" do
      @provider.expects(:projmod).with() { |*arguments|
        arguments.size == 6
        arguments.pop.should == 'proj1'
        arguments[0].should == '-r'
        arguments[1].should == '-K'
        arguments[3].should == '-K'
        arguments.should include 'key99'
        arguments.should include 'key1=value1'
      }
      @provider.stubs(:get).with(:attributes).returns(:key99 => nil, :key1 => 'value1')
      @provider.attributes=({})
    end

  end
end
