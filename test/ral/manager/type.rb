#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'mocha'
require 'puppettest'

class TestType < Test::Unit::TestCase
  include PuppetTest
  def test_typemethods
    Puppet::Type.eachtype { |type|
      name = nil
      assert_nothing_raised("Searching for name for #{type} caused failure") {
          name = type.name
      }

      assert(name, "Could not find name for #{type}")


            assert_equal(
                
        type,
        Puppet::Type.type(name),
        
        "Failed to retrieve #{name} by name"
      )

      # Skip types with no parameters or valid properties
      #unless ! type.parameters.empty? or ! type.validproperties.empty?
      #    next
      #end

      assert_nothing_raised {

              assert_not_nil(
                
          type.properties,
        
          "Properties for #{name} are nil"
        )


              assert_not_nil(
                
          type.validproperties,
        
          "Valid properties for #{name} are nil"
        )
      }
    }
  end

  def test_aliases_are_added_to_catalog

          resource = Puppet::Type.type(:file).new(
                
      :name => "/path/to/some/missing/file",
        
      :ensure => "file"
    )
    resource.stubs(:path).returns("")

    catalog = stubs 'catalog'
    catalog.stubs(:resource).returns(nil)
    catalog.expects(:alias).with(resource, "funtest")
    resource.catalog = catalog

    assert_nothing_raised("Could not add alias") {
      resource[:alias] = "funtest"
    }
  end

  def test_aliasing_fails_without_a_catalog

          resource = Puppet::Type.type(:file).new(
                
      :name => "/no/such/file",
        
      :ensure => "file"
    )

    assert_raise(Puppet::Error, "It should fail to alias when no catalog was available") {
      resource[:alias] = "funtest"
    }
  end

  def test_ensuredefault
    user = nil
    assert_nothing_raised {

            user = Puppet::Type.type(:user).new(
                
        :name => "pptestAA",
        
        :check => [:uid]
      )
    }

    # make sure we don't get :ensure for unmanaged files
    assert(! user.property(:ensure), "User got an ensure property")

    assert_nothing_raised {

            user = Puppet::Type.type(:user).new(
                
        :name => "pptestAB",
        
        :comment => "Testingness"
      )
    }
    # but make sure it gets added once we manage them
    assert(user.property(:ensure), "User did not add ensure property")

    assert_nothing_raised {

            user = Puppet::Type.type(:user).new(
                
        :name => "pptestBC",
        
        :comment => "A fake user"
      )
    }

    # and make sure managed objects start with them
    assert(user.property(:ensure), "User did not get an ensure property")
  end
  def test_newtype_methods
    assert_nothing_raised {
      Puppet::Type.newtype(:mytype) do
        newparam(:wow) do isnamevar end
      end
    }


          assert(
        Puppet::Type.respond_to?(:newmytype),
        
      "new<type> method did not get created")

    obj = nil
    assert_nothing_raised {
      obj = Puppet::Type.newmytype(:wow => "yay")
    }

    assert(obj.is_a?(Puppet::Type.type(:mytype)),
      "Obj is not the correct type")

    # Now make the type again, just to make sure it works on refreshing.
    assert_nothing_raised {
      Puppet::Type.newtype(:mytype) do
        newparam(:yay) do isnamevar end
      end
    }

    obj = nil
    # Make sure the old class was thrown away and only the new one is sitting
    # around.
    assert_raise(Puppet::Error) {
      obj = Puppet::Type.newmytype(:wow => "yay")
    }
    assert_nothing_raised {
      obj = Puppet::Type.newmytype(:yay => "yay")
    }

    # Now make sure that we don't replace existing, non-type methods
    parammethod = Puppet::Type.method(:newparam)

    assert_nothing_raised {
      Puppet::Type.newtype(:param) do
        newparam(:rah) do isnamevar end
      end
    }
    assert_equal(parammethod, Puppet::Type.method(:newparam), "newparam method got replaced by newtype")
  end

  def test_newproperty_options
    # Create a type with a fake provider
    providerclass = Class.new do
      def self.supports_parameter?(prop)
        true
      end
      def method_missing(method, *args)
        method
      end
    end
    self.class.const_set("ProviderClass", providerclass)

    type = Puppet::Type.newtype(:mytype) do
      newparam(:name) do
        isnamevar
      end
      def provider
        @provider ||= ProviderClass.new

        @provider
      end
    end

    # Now make a property with no options.
    property = nil
    assert_nothing_raised do
      property = type.newproperty(:noopts) do
      end
    end

    # Now create an instance
    obj = type.create(:name => :myobj)

    inst = property.new(:resource => obj)

    # And make sure it's correctly setting @is
    ret = nil
    assert_nothing_raised {
      ret = inst.retrieve
    }

    assert_equal(:noopts, inst.retrieve)

    # Now create a property with a different way of doing it
    property = nil
    assert_nothing_raised do
      property = type.newproperty(:setretrieve, :retrieve => :yayness)
    end

    inst = property.new(:resource => obj)

    # And make sure it's correctly setting @is
    ret = nil
    assert_nothing_raised {
      ret = inst.retrieve
    }

    assert_equal(:yayness, ret)
  end

  # Make sure the title is sufficiently differentiated from the namevar.
  def test_title_at_creation_with_hash
    file = nil
    fileclass = Puppet::Type.type(:file)

    path = tempfile
    assert_nothing_raised do

            file = fileclass.create(
                
        :title => "Myfile",
        
        :path => path
      )
    end

    assert_equal("Myfile", file.title, "Did not get correct title")
    assert_equal(path, file[:name], "Did not get correct name")

    file = nil

    # Now make sure we can specify both and still get the right answers
    assert_nothing_raised do

            file = fileclass.create(
                
        :title => "Myfile",
        
        :name => path
      )
    end

    assert_instance_of(fileclass, file)

    assert_equal("Myfile", file.title, "Did not get correct title")
    assert_equal(path, file[:name], "Did not get correct name")
  end

  # Make sure that we can have multiple non-isomorphic objects with the same name,
  # but not with isomorphic objects.
  def test_isomorphic_names
    catalog = mk_catalog
    # First do execs, since they're not isomorphic.
    echo = Puppet::Util.which "echo"
    exec1 = exec2 = nil
    assert_nothing_raised do

            exec1 = Puppet::Type.type(:exec).new(
                
        :title => "exec1",
        
        :command => "#{echo} funtest"
      )
    end
    catalog.add_resource(exec1)
    assert_nothing_raised do

            exec2 = Puppet::Type.type(:exec).new(
                
        :title => "exec2",
        
        :command => "#{echo} funtest"
      )
    end
    catalog.add_resource(exec2)

    # Now do files, since they are. This should fail.
    file1 = file2 = nil
    path = tempfile

          file1 = Puppet::Type.type(:file).new(
                
      :title => "file1",
      :path => path,
        
      :content => "yayness"
    )
    catalog.add_resource(file1)


          file2 = Puppet::Type.type(:file).new(
                
      :title => "file2",
      :path => path,
        
      :content => "rahness"
    )
    assert_raise(ArgumentError) { catalog.add_resource(file2) }
  end

  def test_tags
    obj = Puppet::Type.type(:file).new(:path => tempfile)

    tags = ["some", "test", "tags"]

    obj.tags = tags

    # tags can be stored in an unordered set, so we sort
    # them for the assert_equal to work
    assert_equal((tags << "file").sort, obj.tags.sort)
  end

  def test_to_hash
    file = Puppet::Type.newfile :path => tempfile, :owner => "luke",
      :recurse => true, :loglevel => "warning"

    hash = nil
    assert_nothing_raised do
      hash = file.to_hash
    end

    [:path, :owner, :recurse, :loglevel].each do |param|
      assert(hash[param], "Hash did not include #{param}")
    end
  end

  def test_ref
    path = tempfile
    Puppet::Type.type(:exec) # uggh, the methods need to load the types
    file = Puppet::Type.newfile(:path => path)
    assert_equal("File[#{path}]", file.ref)

    exec = Puppet::Type.newexec(:title => "yay", :command => "/bin/echo yay")
    assert_equal("Exec[yay]", exec.ref)
  end
end
