require 'spec_helper'
require 'puppet_spec/compiler'
require 'puppet/property/boolean'

Puppet::Type.newtype(:type_test) do
  ensurable
  newparam(:name, isnamevar: true)
  newproperty(:device)
  newproperty(:blockdevice)
  newproperty(:fstype)
  newproperty(:options)
  newproperty(:pass)
  newproperty(:atboot, parent: Puppet::Property::Boolean) do
    def munge(value)
      munged = super
      if munged
        :yes
      else
        :no
      end
    end
  end
  newparam(:remounts) do
    newvalues(:true, :false)
    defaultto do
      true
    end
  end
end
Puppet::Type.type(:type_test).provide(:type_test) do
  mk_resource_methods
end

describe Puppet::Type, :unless => Puppet::Util::Platform.windows? do
  include PuppetSpec::Files
  include PuppetSpec::Compiler

  let(:resource_type) { :type_test }
  let(:klass) { Puppet::Type.type(resource_type) }
  let(:ref_type) { klass.name.to_s.capitalize }

  it "should be Comparable" do
    a = Puppet::Type.type(:notify).new(:name => "a")
    b = Puppet::Type.type(:notify).new(:name => "b")
    c = Puppet::Type.type(:notify).new(:name => "c")

    [[a, b, c], [a, c, b], [b, a, c], [b, c, a], [c, a, b], [c, b, a]].each do |this|
      expect(this.sort).to eq([a, b, c])
    end

    expect(a).to be < b
    expect(a).to be < c
    expect(b).to be > a
    expect(b).to be < c
    expect(c).to be > a
    expect(c).to be > b

    [a, b, c].each {|x| expect(a).to be <= x }
    [a, b, c].each {|x| expect(c).to be >= x }

    expect(b).to be_between(a, c)
  end

  it "should consider a parameter to be valid if it is a valid parameter" do
    expect(klass).to be_valid_parameter(:name)
  end

  it "should consider a parameter to be valid if it is a valid property" do
    expect(klass).to be_valid_parameter(:fstype)
  end

  it "should consider a parameter to be valid if it is a valid metaparam" do
    expect(klass).to be_valid_parameter(:noop)
  end

  it "should be able to retrieve a property by name" do
    resource = klass.new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present)
    expect(resource.property(:fstype)).to be_instance_of(klass.attrclass(:fstype))
  end

  it "should be able to retrieve a parameter by name" do
    resource = klass.new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present)
    expect(resource.parameter(:name)).to be_instance_of(klass.attrclass(:name))
  end

  it "should be able to retrieve a property by name using the :parameter method" do
    resource = klass.new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present)
    expect(resource.parameter(:fstype)).to be_instance_of(klass.attrclass(:fstype))
  end

  it "should be able to retrieve all set properties" do
    resource = klass.new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present)
    props = resource.properties
    expect(props).not_to be_include(nil)
    [:fstype, :ensure, :pass].each do |name|
      expect(props).to be_include(resource.parameter(name))
    end
  end

  it "can retrieve all set parameters" do
    resource = klass.new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present, :tag => 'foo')
    params = resource.parameters_with_value
    [:name, :provider, :ensure, :fstype, :pass, :loglevel, :tag].each do |name|
      expect(params).to be_include(resource.parameter(name))
    end
  end

  it "can not return any `nil` values when retrieving all set parameters" do
    resource = klass.new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present, :tag => 'foo')
    params = resource.parameters_with_value
    expect(params).not_to be_include(nil)
  end

  it "can return an iterator for all set parameters" do
    resource = Puppet::Type.type(:notify).new(:name=>'foo',:message=>'bar',:tag=>'baz',:require=> "File['foo']")
    params = [:name, :message, :withpath, :loglevel, :tag, :require]
    resource.eachparameter { |param|
      expect(params).to be_include(param.to_s.to_sym)
    }
  end

  it "should have a method for setting default values for resources" do
    expect(klass.new(:name => "foo")).to respond_to(:set_default)
  end

  it "should do nothing for attributes that have no defaults and no specified value" do
    expect(klass.new(:name => "foo").parameter(:noop)).to be_nil
  end

  it "should have a method for adding tags" do
    expect(klass.new(:name => "foo")).to respond_to(:tags)
  end

  it "should use the tagging module" do
    expect(klass.ancestors).to be_include(Puppet::Util::Tagging)
  end

  it "should delegate to the tagging module when tags are added" do
    resource = klass.new(:name => "foo")
    allow(resource).to receive(:tag).with(resource_type)

    expect(resource).to receive(:tag).with(:tag1, :tag2)

    resource.tags = [:tag1,:tag2]
  end

  it "should add the current type as tag" do
    resource = klass.new(:name => "foo")
    allow(resource).to receive(:tag)

    expect(resource).to receive(:tag).with(resource_type)

    resource.tags = [:tag1,:tag2]
  end

  it "should have a method to know if the resource is exported" do
    expect(klass.new(:name => "foo")).to respond_to(:exported?)
  end

  it "should have a method to know if the resource is virtual" do
    expect(klass.new(:name => "foo")).to respond_to(:virtual?)
  end

  it "should consider its version to be zero if it has no catalog" do
    expect(klass.new(:name => "foo").version).to eq(0)
  end

  it "reports the correct path even after path is used during setup of the type" do
    Puppet::Type.newtype(:testing) do
      newparam(:name) do
        isnamevar
        validate do |value|
          path # forces the computation of the path
        end
      end
    end

    ral = compile_to_ral(<<-MANIFEST)
      class something {
        testing { something: }
      }
      include something
    MANIFEST

    expect(ral.resource("Testing[something]").path).to eq("/Stage[main]/Something/Testing[something]")
  end

  context "alias metaparam" do
    it "creates a new name that can be used for resource references" do
      ral = compile_to_ral(<<-MANIFEST)
        notify { a: alias => c }
      MANIFEST

      expect(ral.resource("Notify[a]")).to eq(ral.resource("Notify[c]"))
    end
  end

  context 'aliased resource' do
    it 'fails if a resource is defined and then redefined using name that results in the same alias' do
      drive = Puppet::Util::Platform.windows? ? 'C:' : ''
      code = <<~PUPPET
        $dir='#{drive}/tmp/test'
        $same_dir='#{drive}/tmp/test/'

        file {$dir:
          ensure => directory
        }

        file { $same_dir:
          ensure => directory
        }
      PUPPET

      expect { compile_to_ral(code) }.to raise_error(/resource \["File", "#{drive}\/tmp\/test"\] already declared/)
    end
  end

  context "resource attributes" do
    let(:resource) {
      resource = klass.new(:name => "foo")
      catalog = Puppet::Resource::Catalog.new
      catalog.version = 50
      catalog.add_resource resource
      resource
    }

    it "should consider its version to be its catalog version" do
      expect(resource.version).to eq(50)
    end

    it "should have tags" do
      expect(resource).to be_tagged(resource_type.to_s)
      expect(resource).to be_tagged("foo")
    end

    it "should have a path" do
      expect(resource.path).to eq("/#{ref_type}[foo]")
    end
  end

  it "should consider its type to be the name of its class" do
    expect(klass.new(:name => "foo").type).to eq(resource_type)
  end

  it "should use any provided noop value" do
    expect(klass.new(:name => "foo", :noop => true)).to be_noop
  end

  it "should use the global noop value if none is provided" do
    Puppet[:noop] = true
    expect(klass.new(:name => "foo")).to be_noop
  end

  it "should not be noop if in a non-host_config catalog" do
    resource = klass.new(:name => "foo")
    catalog = Puppet::Resource::Catalog.new
    catalog.add_resource resource
    expect(resource).not_to be_noop
  end

  describe "when creating an event" do
    before do
      @resource = klass.new :name => "foo"
    end

    it "should have the resource's reference as the resource" do
      expect(@resource.event.resource).to eq("#{ref_type}[foo]")
    end

    it "should have the resource's log level as the default log level" do
      @resource[:loglevel] = :warning
      expect(@resource.event.default_log_level).to eq(:warning)
    end

    {:file => "/my/file", :line => 50}.each do |attr, value|
      it "should set the #{attr}" do
        allow(@resource).to receive(attr).and_return(value)
        expect(@resource.event.send(attr)).to eq(value)
      end
    end

    it "should set the tags" do
      @resource.tag("abc", "def")
      expect(@resource.event).to be_tagged("abc")
      expect(@resource.event).to be_tagged("def")
    end

    it "should allow specification of event attributes" do
      expect(@resource.event(:status => "noop").status).to eq("noop")
    end
  end

  describe "when creating a provider" do
    before :each do
      @type = Puppet::Type.newtype(:provider_test_type) do
        newparam(:name) { isnamevar }
        newparam(:foo)
        newproperty(:bar)
      end
    end

    after :each do
      @type.provider_hash.clear
    end

    describe "when determining if instances of the type are managed" do
      it "should not consider audit only resources to be managed" do
        expect(@type.new(:name => "foo", :audit => 'all').managed?).to be_falsey
      end

      it "should not consider resources with only parameters to be managed" do
        expect(@type.new(:name => "foo", :foo => 'did someone say food?').managed?).to be_falsey
      end

      it "should consider resources with any properties set to be managed" do
        expect(@type.new(:name => "foo", :bar => 'Let us all go there').managed?).to be_truthy
      end
    end

    it "should have documentation for the 'provider' parameter if there are providers" do
      @type.provide(:test_provider)
      expect(@type.paramdoc(:provider)).to match(/`provider_test_type`[\s]+resource/)
    end

    it "should not have documentation for the 'provider' parameter if there are no providers" do
      expect { @type.paramdoc(:provider) }.to raise_error(NoMethodError)
    end

    it "should create a subclass of Puppet::Provider for the provider" do
      provider = @type.provide(:test_provider)

      expect(provider.ancestors).to include(Puppet::Provider)
    end

    it "should use a parent class if specified" do
      parent_provider = @type.provide(:parent_provider)
      child_provider  = @type.provide(:child_provider, :parent => parent_provider)

      expect(child_provider.ancestors).to include(parent_provider)
    end

    it "should use a parent class if specified by name" do
      parent_provider = @type.provide(:parent_provider)
      child_provider  = @type.provide(:child_provider, :parent => :parent_provider)

      expect(child_provider.ancestors).to include(parent_provider)
    end

    it "should raise an error when the parent class can't be found" do
      expect {
        @type.provide(:child_provider, :parent => :parent_provider)
      }.to raise_error(Puppet::DevError, /Could not find parent provider.+parent_provider/)
    end

    it "should ensure its type has a 'provider' parameter" do
      @type.provide(:test_provider)

      expect(@type.parameters).to include(:provider)
    end

    it "should remove a previously registered provider with the same name" do
      old_provider = @type.provide(:test_provider)
      new_provider = @type.provide(:test_provider)

      expect(old_provider).not_to equal(new_provider)
    end

    it "should register itself as a provider for the type" do
      provider = @type.provide(:test_provider)

      expect(provider).to eq(@type.provider(:test_provider))
    end

    it "should create a provider when a provider with the same name previously failed" do
      @type.provide(:test_provider) do
        raise "failed to create this provider"
      end rescue nil

      provider = @type.provide(:test_provider)

      expect(provider.ancestors).to include(Puppet::Provider)
      expect(provider).to eq(@type.provider(:test_provider))
    end

    describe "with a parent class from another type" do
      before :each do
        @parent_type = Puppet::Type.newtype(:provider_parent_type) do
          newparam(:name) { isnamevar }
        end
        @parent_provider = @parent_type.provide(:parent_provider)
      end

      it "should be created successfully" do
        child_provider = @type.provide(:child_provider, :parent => @parent_provider)
        expect(child_provider.ancestors).to include(@parent_provider)
      end

      it "should be registered as a provider of the child type" do
        @type.provide(:child_provider, :parent => @parent_provider)
        expect(@type.providers).to include(:child_provider)
        expect(@parent_type.providers).not_to include(:child_provider)
      end
    end
  end

  describe "when choosing a default provider" do
    it "should choose the provider with the highest specificity" do
      # Make a fake type
      type = Puppet::Type.newtype(:defaultprovidertest) do
        newparam(:name) do end
      end

      basic = type.provide(:basic) {}
      greater = type.provide(:greater) {}

      allow(basic).to receive(:specificity).and_return(1)
      allow(greater).to receive(:specificity).and_return(2)

      expect(type.defaultprovider).to equal(greater)
    end
  end

  context "autorelations" do
    before :each do
      Puppet::Type.newtype(:autorelation_one) do
        newparam(:name) { isnamevar }
      end
    end

    describe "when building autorelations" do
      it "should be able to autorequire puppet resources" do
        Puppet::Type.newtype(:autorelation_two) do
          newparam(:name) { isnamevar }
          autorequire(:autorelation_one) { Puppet::Type.type(:notify).new(name: 'test') }
        end

        relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
          autorelation_one { 'Notify[test]': }
          autorelation_two { 'bar': }
        MANIFEST

        src = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Notify[test]' }.first
        dst = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_two[bar]' }.first

        expect(relationship_graph.edge?(src,dst)).to be_truthy
        expect(relationship_graph.edges_between(src,dst).first.event).to eq(:NONE)
      end

      it "should be able to autorequire resources" do
        Puppet::Type.newtype(:autorelation_two) do
          newparam(:name) { isnamevar }
          autorequire(:autorelation_one) { ['foo'] }
        end

        relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
          autorelation_one { 'foo': }
          autorelation_two { 'bar': }
        MANIFEST

        src = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_one[foo]' }.first
        dst = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_two[bar]' }.first

        expect(relationship_graph.edge?(src,dst)).to be_truthy
        expect(relationship_graph.edges_between(src,dst).first.event).to eq(:NONE)
      end

      it 'should not fail autorequire contains undef entries' do
        Puppet::Type.newtype(:autorelation_two) do
          newparam(:name) { isnamevar }
          autorequire(:autorelation_one) { [nil, 'foo'] }
        end

        relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
          autorelation_one { 'foo': }
          autorelation_two { 'bar': }
        MANIFEST

        src = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_one[foo]' }.first
        dst = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_two[bar]' }.first

        expect(relationship_graph.edge?(src,dst)).to be_truthy
        expect(relationship_graph.edges_between(src,dst).first.event).to eq(:NONE)
      end

      it "should be able to autosubscribe resources" do
        Puppet::Type.newtype(:autorelation_two) do
          newparam(:name) { isnamevar }
          autosubscribe(:autorelation_one) { ['foo'] }
        end

        relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
          autorelation_one { 'foo': }
          autorelation_two { 'bar': }
        MANIFEST

        src = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_one[foo]' }.first
        dst = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_two[bar]' }.first

        expect(relationship_graph.edge?(src,dst)).to be_truthy
        expect(relationship_graph.edges_between(src,dst).first.event).to eq(:ALL_EVENTS)
      end

      it 'should not fail if autosubscribe contains undef entries' do
        Puppet::Type.newtype(:autorelation_two) do
          newparam(:name) { isnamevar }
          autosubscribe(:autorelation_one) { [nil, 'foo'] }
        end

        relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
          autorelation_one { 'foo': }
          autorelation_two { 'bar': }
        MANIFEST

        src = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_one[foo]' }.first
        dst = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_two[bar]' }.first

        expect(relationship_graph.edge?(src,dst)).to be_truthy
        expect(relationship_graph.edges_between(src,dst).first.event).to eq(:ALL_EVENTS)
      end

      it "should be able to autobefore resources" do
        Puppet::Type.newtype(:autorelation_two) do
          newparam(:name) { isnamevar }
          autobefore(:autorelation_one) { ['foo'] }
        end

        relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
          autorelation_one { 'foo': }
          autorelation_two { 'bar': }
        MANIFEST

        src = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_two[bar]' }.first
        dst = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_one[foo]' }.first

        expect(relationship_graph.edge?(src,dst)).to be_truthy
        expect(relationship_graph.edges_between(src,dst).first.event).to eq(:NONE)
      end

      it "should not fail when autobefore contains undef entries" do
        Puppet::Type.newtype(:autorelation_two) do
          newparam(:name) { isnamevar }
          autobefore(:autorelation_one) { [nil, 'foo'] }
        end

        relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
          autorelation_one { 'foo': }
          autorelation_two { 'bar': }
        MANIFEST

        src = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_two[bar]' }.first
        dst = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_one[foo]' }.first

        expect(relationship_graph.edge?(src,dst)).to be_truthy
        expect(relationship_graph.edges_between(src,dst).first.event).to eq(:NONE)
      end

      it "should be able to autonotify resources" do
        Puppet::Type.newtype(:autorelation_two) do
          newparam(:name) { isnamevar }
          autonotify(:autorelation_one) { ['foo'] }
        end

        relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
          autorelation_one { 'foo': }
          autorelation_two { 'bar': }
        MANIFEST

        src = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_two[bar]' }.first
        dst = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_one[foo]' }.first

        expect(relationship_graph.edge?(src,dst)).to be_truthy
        expect(relationship_graph.edges_between(src,dst).first.event).to eq(:ALL_EVENTS)
      end

      it 'should not fail if autonotify contains undef entries' do
        Puppet::Type.newtype(:autorelation_two) do
          newparam(:name) { isnamevar }
          autonotify(:autorelation_one) { [nil, 'foo'] }
        end

        relationship_graph = compile_to_relationship_graph(<<-MANIFEST)
          autorelation_one { 'foo': }
          autorelation_two { 'bar': }
        MANIFEST

        src = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_two[bar]' }.first
        dst = relationship_graph.vertices.select{ |x| x.ref.to_s == 'Autorelation_one[foo]' }.first

        expect(relationship_graph.edge?(src,dst)).to be_truthy
        expect(relationship_graph.edges_between(src,dst).first.event).to eq(:ALL_EVENTS)
      end
    end
  end

  describe "when initializing" do
    describe "and passed a Puppet::Resource instance" do
      it "should set its title to the title of the resource if the resource type is equal to the current type" do
        resource = Puppet::Resource.new(resource_type, "/foo", :parameters => {:name => "/other"})
        expect(klass.new(resource).title).to eq("/foo")
      end

      it "should set its title to the resource reference if the resource type is not equal to the current type" do
        resource = Puppet::Resource.new(:user, "foo")
        expect(klass.new(resource).title).to eq("User[foo]")
      end

      [:line, :file, :catalog, :exported, :virtual].each do |param|
        it "should copy '#{param}' from the resource if present" do
          resource = Puppet::Resource.new(resource_type, "/foo")
          resource.send(param.to_s + "=", "foo")
          resource.send(param.to_s + "=", "foo")
          expect(klass.new(resource).send(param)).to eq("foo")
        end
      end

      it "should copy any tags from the resource" do
        resource = Puppet::Resource.new(resource_type, "/foo")
        resource.tag "one", "two"
        tags = klass.new(resource).tags
        expect(tags).to be_include("one")
        expect(tags).to be_include("two")
      end

      it "should copy the resource's parameters as its own" do
        resource = Puppet::Resource.new(resource_type, "/foo", :parameters => {:atboot => :yes, :fstype => "boo"})
        params = klass.new(resource).to_hash
        expect(params[:fstype]).to eq("boo")
        expect(params[:atboot]).to eq(:yes)
      end

      it "copies sensitive parameters to the appropriate properties" do
        resource = Puppet::Resource.new(resource_type, "/foo",
                                        :parameters => {:atboot => :yes, :fstype => "boo"},
                                        :sensitive_parameters => [:fstype])
        type = klass.new(resource)
        expect(type.property(:fstype).sensitive).to eq true
      end

      it "logs a warning when a parameter is marked as sensitive" do
        resource = Puppet::Resource.new(resource_type, "/foo",
                                        :parameters => {:atboot => :yes, :fstype => "boo", :remounts => true},
                                        :sensitive_parameters => [:remounts])
        expect_any_instance_of(klass).to receive(:warning).with(/Unable to mark 'remounts' as sensitive: remounts is a parameter and not a property/)
        klass.new(resource)
      end

      it "logs a warning when a property is not set but is marked as sensitive" do
        resource = Puppet::Resource.new(resource_type, "/foo",
                                        :parameters => {:atboot => :yes, :fstype => "boo"},
                                        :sensitive_parameters => [:device])
        expect_any_instance_of(klass).to receive(:warning).with("Unable to mark 'device' as sensitive: the property itself was not assigned a value.")
        klass.new(resource)
      end

      it "logs an error when a property is not defined on the type but is marked as sensitive" do
        resource = Puppet::Resource.new(resource_type, "/foo",
                                        :parameters => {:atboot => :yes, :fstype => "boo"},
                                        :sensitive_parameters => [:content])
        expect_any_instance_of(klass).to receive(:err).with("Unable to mark 'content' as sensitive: the property itself is not defined on #{resource_type}.")
        klass.new(resource)
      end
    end

    describe "and passed a Hash" do
      it "should extract the title from the hash" do
        expect(klass.new(:title => "/yay").title).to eq("/yay")
      end

      it "should work when hash keys are provided as strings" do
        expect(klass.new("title" => "/yay").title).to eq("/yay")
      end

      it "should work when hash keys are provided as symbols" do
        expect(klass.new(:title => "/yay").title).to eq("/yay")
      end

      it "should use the name from the hash as the title if no explicit title is provided" do
        expect(klass.new(:name => "/yay").title).to eq("/yay")
      end

      it "should use the Resource Type's namevar to determine how to find the name in the hash" do
        yay = make_absolute('/yay')
        expect(Puppet::Type.type(:file).new(:path => yay).title).to eq(yay)
      end

      [:catalog].each do |param|
        it "should extract '#{param}' from the hash if present" do
          expect(klass.new(:name => "/yay", param => "foo").send(param)).to eq("foo")
        end
      end

      it "should use any remaining hash keys as its parameters" do
        resource = klass.new(:title => "/foo", :catalog => "foo", :atboot => :yes, :fstype => "boo")
        expect(resource[:fstype]).to eq("boo")
        expect(resource[:atboot]).to eq(:yes)
      end
    end

    it "should fail if any invalid attributes have been provided" do
      expect { klass.new(:title => "/foo", :nosuchattr => "whatever") }.to raise_error(Puppet::Error, /no parameter named 'nosuchattr'/)
    end

    context "when an attribute fails validation" do
      it "should fail with Puppet::ResourceError when PuppetError raised" do
        expect { Puppet::Type.type(:file).new(:title => "/foo", :source => "unknown:///") }.to raise_error(Puppet::ResourceError, /Parameter source failed on File\[.*foo\]/)
      end

      it "should fail with Puppet::ResourceError when ArgumentError raised" do
        expect { Puppet::Type.type(:file).new(:title => "/foo", :mode => "abcdef") }.to raise_error(Puppet::ResourceError, /Parameter mode failed on File\[.*foo\]/)
      end

      it "should include the file/line in the error" do
        allow_any_instance_of(Puppet::Type.type(:file)).to receive(:file).and_return("example.pp")
        allow_any_instance_of(Puppet::Type.type(:file)).to receive(:line).and_return(42)
        expect { Puppet::Type.type(:file).new(:title => "/foo", :source => "unknown:///") }.to raise_error(Puppet::ResourceError, /\(file: example\.pp, line: 42\)/)
      end
    end

    it "should set its name to the resource's title if the resource does not have a :name or namevar parameter set" do
      resource = Puppet::Resource.new(resource_type, "/foo")

      expect(klass.new(resource).name).to eq("/foo")
    end

    it "should fail if no title, name, or namevar are provided" do
      expect { klass.new(:atboot => :yes) }.to raise_error(Puppet::Error)
    end

    it "should set the attributes in the order returned by the class's :allattrs method" do
      allow(klass).to receive(:allattrs).and_return([:name, :atboot, :noop])
      resource = Puppet::Resource.new(resource_type, "/foo", :parameters => {:name => "myname", :atboot => :yes, :noop => "whatever"})

      set = []

      allow_any_instance_of(klass).to receive(:newattr) do |_, param, hash|
        set << param
        double("a property", :value= => nil, :default => nil, :name => nil)
      end

      klass.new(resource)

      expect(set[-1]).to eq(:noop)
      expect(set[-2]).to eq(:atboot)
    end

    it "should always set the name and then default provider before anything else" do
      allow(klass).to receive(:allattrs).and_return([:provider, :name, :atboot])
      resource = Puppet::Resource.new(resource_type, "/foo", :parameters => {:name => "myname", :atboot => :yes})

      set = []

      allow_any_instance_of(klass).to receive(:newattr) do |_, param, hash|
        set << param
        double("a property", :value= => nil, :default => nil, :name => nil)
      end

      klass.new(resource)
      expect(set[0]).to eq(:name)
      expect(set[1]).to eq(:provider)
    end

    # This one is really hard to test :/
    it "should set each default immediately if no value is provided" do
      # We have a :confine block that calls execute in our upstart provider, which fails
      # on jruby. Thus, we stub it out here since we don't care to do any assertions on it.
      # This is only an issue if you're running these unit tests on a platform where upstart
      # is a default provider, like Ubuntu trusty.
      allow(Puppet::Util::Execution).to receive(:execute)

      defaults = []
      allow_any_instance_of(Puppet::Type.type(:service)).to receive(:set_default) { |_, value| defaults << value }

      Puppet::Type.type(:service).new :name => "whatever"

      expect(defaults[0]).to eq(:provider)
    end

    it "should retain a copy of the originally provided parameters" do
      expect(klass.new(:name => "foo", :atboot => :yes, :noop => false).original_parameters).to eq({:atboot => :yes, :noop => false})
    end

    it "should delete the name via the namevar from the originally provided parameters" do
      expect(Puppet::Type.type(:file).new(:name => make_absolute('/foo')).original_parameters[:path]).to be_nil
    end

    context "when validating the resource" do
      it "should call the type's validate method if present" do
        expect_any_instance_of(Puppet::Type.type(:file)).to receive(:validate)
        Puppet::Type.type(:file).new(:name => make_absolute('/foo'))
      end

      it "should raise Puppet::ResourceError with resource name when Puppet::Error raised" do
        expect do
          Puppet::Type.type(:file).new(
            :name => make_absolute('/foo'),
            :source => "puppet:///",
            :content => "foo"
          )
        end.to raise_error(Puppet::ResourceError, /Validation of File\[.*foo.*\]/)
      end

      it "should raise Puppet::ResourceError with manifest file and line on failure" do
        allow_any_instance_of(Puppet::Type.type(:file)).to receive(:file).and_return("example.pp")
        allow_any_instance_of(Puppet::Type.type(:file)).to receive(:line).and_return(42)
        expect do
          Puppet::Type.type(:file).new(
            :name => make_absolute('/foo'),
            :source => "puppet:///",
            :content => "foo"
          )
        end.to raise_error(Puppet::ResourceError, /Validation.*\(file: example\.pp, line: 42\)/)
      end
    end
  end

  describe "#set_sensitive_parameters" do
    let(:sensitive_type) do
      Puppet::Type.newtype(:sensitive_test) do
        newparam(:name) { isnamevar }
        newproperty(:secret) do
          newvalues(/.*/)
          sensitive true
        end
        newproperty(:transparency) do
          newvalues(/.*/)
          sensitive false
        end
        newproperty(:things) { newvalues(/.*/) }
      end
    end

    it "should mark properties as sensitive" do
      resource = sensitive_type.new(:name => 'foo', :secret => 'uber classified')
      expect(resource.parameters[:secret].sensitive).to be true
    end

    it "should not have a sensitive flag when not set" do
      resource = sensitive_type.new(:name => 'foo', :things => '1337')
      expect(resource.parameters[:things].sensitive).to be_nil
    end

    it "should define things as not sensitive" do
      resource = sensitive_type.new(:name => 'foo', :transparency => 'public knowledge')
      expect(resource.parameters[:transparency].sensitive).to be false
    end

    it "should honor when sensitivity is set in a manifest" do
      resource = sensitive_type.new(:name => 'foo',
                                    :transparency => Puppet::Pops::Types::PSensitiveType::Sensitive.new('top secret'),
                                    :sensitive_parameters => [:transparency]
                                    )
      expect(resource.parameters[:transparency].sensitive).to be true
    end
  end

  describe "when #finish is called on a type" do
    let(:post_hook_type) do
      Puppet::Type.newtype(:finish_test) do
        newparam(:name) { isnamevar }

        newparam(:post) do
          def post_compile
            raise "post_compile hook ran"
          end
        end
      end
    end

    let(:post_hook_resource) do
      post_hook_type.new(:name => 'foo',:post => 'fake_value')
    end

    it "should call #post_compile on parameters that implement it" do
      expect { post_hook_resource.finish }.to raise_error(RuntimeError, "post_compile hook ran")
    end
  end

  it "should have a class method for converting a hash into a Puppet::Resource instance" do
    expect(klass).to respond_to(:hash2resource)
  end

  describe "when converting a hash to a Puppet::Resource instance" do
    before do
      @type = klass
    end

    it "should treat a :title key as the title of the resource" do
      expect(@type.hash2resource(:name => "/foo", :title => "foo").title).to eq("foo")
    end

    it "should use the name from the hash as the title if no explicit title is provided" do
      expect(@type.hash2resource(:name => "foo").title).to eq("foo")
    end

    it "should use the Resource Type's namevar to determine how to find the name in the hash" do
      allow(@type).to receive(:key_attributes).and_return([ :myname ])

      expect(@type.hash2resource(:myname => "foo").title).to eq("foo")
    end

    [:catalog].each do |attr|
      it "should use any provided #{attr}" do
        expect(@type.hash2resource(:name => "foo", attr => "eh").send(attr)).to eq("eh")
      end
    end

    it "should set all provided parameters on the resource" do
      expect(@type.hash2resource(:name => "foo", :fstype => "boo", :boot => "fee").to_hash).to eq({:name => "foo", :fstype => "boo", :boot => "fee"})
    end

    it "should not set the title as a parameter on the resource" do
      expect(@type.hash2resource(:name => "foo", :title => "eh")[:title]).to be_nil
    end

    it "should not set the catalog as a parameter on the resource" do
      expect(@type.hash2resource(:name => "foo", :catalog => "eh")[:catalog]).to be_nil
    end

    it "should treat hash keys equivalently whether provided as strings or symbols" do
      resource = @type.hash2resource("name" => "foo", "title" => "eh", "fstype" => "boo")
      expect(resource.title).to eq("eh")
      expect(resource[:name]).to eq("foo")
      expect(resource[:fstype]).to eq("boo")
    end
  end

  describe "when retrieving current property values" do
    before do
      @resource = klass.new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present)
      allow(@resource.property(:ensure)).to receive(:retrieve).and_return(:absent)
    end

    it "should always retrieve the ensure value by default" do
      @ensurable_resource = Puppet::Type.type(:file).new(:name => "/not/existent", :mode => "0644")
      # the ensure property is lazily metaprogrammed...
      allow_any_instance_of(Puppet::Type::File::Ensure).to receive(:retrieve).and_return(:absent)
      @ensurable_resource.retrieve_resource
    end

    it "should not retrieve the ensure value if specified" do
      @ensurable_resource = Puppet::Type.type(:service).new(:name => "DummyService", :enable => true)
      @ensurable_resource.properties.each { |prop| allow(prop).to receive(:retrieve) }
      expect_any_instance_of(Puppet::Type::Service::Ensure).not_to receive(:retrieve)
      @ensurable_resource.retrieve_resource
    end

    it "should fail if its provider is unsuitable" do
      @resource = klass.new(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present)
      expect(@resource.provider.class).to receive(:suitable?).and_return(false)
      expect { @resource.retrieve_resource }.to raise_error(Puppet::Error)
    end

    it "should return a Puppet::Resource instance with its type and title set appropriately" do
      result = @resource.retrieve_resource
      expect(result).to be_instance_of(Puppet::Resource)
      expect(result.type).to eq(ref_type)
      expect(result.title).to eq("foo")
    end

    it "should set the name of the returned resource if its own name and title differ" do
      @resource[:name] = "myname"
      @resource.title = "other name"
      expect(@resource.retrieve_resource[:name]).to eq("myname")
    end

    it "should provide a value for all set properties" do
      values = @resource.retrieve_resource
      [:ensure, :fstype, :pass].each { |property| expect(values[property]).not_to be_nil }
    end

    it "should provide a value for 'ensure' even if no desired value is provided" do
      @resource = Puppet::Type.type(:file).new(:path => make_absolute("/my/file/that/can't/exist"))
    end

    it "should not call retrieve on non-ensure properties if the resource is absent and should consider the property absent" do
      expect(@resource.property(:ensure)).to receive(:retrieve).and_return(:absent)
      expect(@resource.property(:fstype)).not_to receive(:retrieve)
      expect(@resource.retrieve_resource[:fstype]).to eq(:absent)
    end

    it "should include the result of retrieving each property's current value if the resource is present" do
      expect(@resource.property(:ensure)).to receive(:retrieve).and_return(:present)
      expect(@resource.property(:fstype)).to receive(:retrieve).and_return(15)
      @resource.retrieve_resource[:fstype] == 15
    end
  end

  describe "#to_resource" do
    it "should return a Puppet::Resource that includes properties, parameters and tags" do
      type_resource = klass.new(
        :ensure   => :present,
        :name     => "foo",
        :fstype   => "bar",
        :remounts => true
      )
      type_resource.tags = %w{bar baz}

      # If it's not a property it's a parameter
      expect(type_resource.parameters[:remounts]).not_to be_a(Puppet::Property)
      expect(type_resource.parameters[:fstype].is_a?(Puppet::Property)).to be_truthy

      expect(type_resource.property(:ensure)).to receive(:retrieve).and_return(:present)
      expect(type_resource.property(:fstype)).to receive(:retrieve).and_return(15)

      resource = type_resource.to_resource

      expect(resource).to be_a Puppet::Resource
      expect(resource[:fstype]).to   eq(15)
      expect(resource[:remounts]).to eq(:true)
      expect(resource.tags).to eq(Puppet::Util::TagSet.new(%w{foo bar baz} + [resource_type.to_s]))
    end
  end

  describe ".title_patterns" do
    describe "when there's one namevar" do
      before do
        @type_class = Puppet::Type.type(:notify)
        allow(@type_class).to receive(:key_attributes).and_return([:one])
      end

      it "should have a default pattern for when there's one namevar" do
        patterns = @type_class.title_patterns
        expect(patterns.length).to eq(1)
        expect(patterns[0].length).to eq(2)
      end

      it "should have a regexp that captures the entire string" do
        patterns = @type_class.title_patterns
        string = "abc\n\tdef"
        patterns[0][0] =~ string
        expect($1).to eq("abc\n\tdef")
      end
    end
  end

  describe "when in a catalog" do
    before do
      @catalog = Puppet::Resource::Catalog.new
      @container = Puppet::Type.type(:component).new(:name => "container")
      @one = Puppet::Type.type(:file).new(:path => make_absolute("/file/one"))
      @two = Puppet::Type.type(:file).new(:path => make_absolute("/file/two"))

      @catalog.add_resource @container
      @catalog.add_resource @one
      @catalog.add_resource @two
      @catalog.add_edge @container, @one
      @catalog.add_edge @container, @two
    end

    it "should have no parent if there is no in edge" do
      expect(@container.parent).to be_nil
    end

    it "should set its parent to its in edge" do
      expect(@one.parent.ref).to eq(@container.ref)
    end

    after do
      @catalog.clear(true)
    end
  end

  it "should have a 'stage' metaparam" do
    expect(Puppet::Type.metaparamclass(:stage)).to be_instance_of(Class)
  end

  describe "#suitable?" do
    let(:type) { Puppet::Type.type(:file) }
    let(:resource) { type.new :path => tmpfile('suitable') }
    let(:provider) { resource.provider }

    it "should be suitable if its type doesn't use providers" do
      allow(type).to receive(:paramclass).with(:provider).and_return(nil)
      expect(resource).to be_suitable
    end

    it "should be suitable if it has a provider which is suitable" do
      expect(resource).to be_suitable
    end

    it "should not be suitable if it has a provider which is not suitable" do
      allow(provider.class).to receive(:suitable?).and_return(false)
      expect(resource).not_to be_suitable
    end

    it "should be suitable if it does not have a provider and there is a default provider" do
      allow(resource).to receive(:provider).and_return(nil)
      expect(resource).to be_suitable
    end

    it "should not be suitable if it doesn't have a provider and there is not default provider" do
      allow(resource).to receive(:provider).and_return(nil)
      allow(type).to receive(:defaultprovider).and_return(nil)

      expect(resource).not_to be_suitable
    end
  end

  describe "::instances" do
    after :each do Puppet::Type.rmtype(:type_spec_fake_type) end
    let :type do
      Puppet::Type.newtype(:type_spec_fake_type) do
        newparam(:name) do
          isnamevar
        end

        newproperty(:prop1) {}
      end

      Puppet::Type.type(:type_spec_fake_type)
    end

    it "should not fail if no suitable providers are found" do
      type.provide(:fake1) do
        confine :exists => '/no/such/file'
        mk_resource_methods
      end

      expect { expect(type.instances).to eq([]) }.to_not raise_error
    end

    context "with a composite namevar type" do
      let :type do
        Puppet::Type.newtype(:type_spec_fake_type) do
          newparam(:name) do
            isnamevar
          end

          newparam(:path) do
            isnamevar
          end

          def self.title_patterns
            [[%r{^(.*)@(.*)$}, [:name, :path]], [%r{^([^@]+)$}, [:name]]]
          end

          newproperty(:prop1) {}
        end

        Puppet::Type.type(:type_spec_fake_type)
      end

      before :each do
        type.provide(:default) do
          defaultfor 'os.name' => Puppet.runtime[:facter].value('os.name')
          mk_resource_methods
          class << self
            attr_accessor :params
          end

          def title
            "#{@property_hash[:name]}@#{@property_hash[:path]}"
          end

          def self.instance(name, path)
            new(:name => name, :path => path, :ensure => :present)
          end

          def self.instances
            @instances ||= params.collect { |param| instance(param.first.to_s, param.last.to_s) }
          end

          @params = [[:name_one, :path_one], [:name_two, :path_two]]
        end
      end

      it "should return composite titles for the instances" do
        expect(type.instances.map(&:title)).to eq(["name_one@path_one", "name_two@path_two"])
      end
    end

    context "with a default provider" do
      before :each do
        type.provide(:default) do
          defaultfor 'os.name' => Puppet.runtime[:facter].value('os.name')
          mk_resource_methods
          class << self
            attr_accessor :names
          end
          def self.instance(name)
            new(:name => name, :ensure => :present)
          end
          def self.instances
            @instances ||= names.collect { |name| instance(name.to_s) }
          end

          @names = [:one, :two]
        end
      end

      it "should return only instances of the type" do
        expect(type.instances).to be_all {|x| x.is_a? type }
      end

      it "should return instances from the default provider" do
        expect(type.instances.map(&:name)).to eq(["one", "two"])
      end

      it "should return instances from all providers" do
        type.provide(:fake1, :parent => :default) { @names = [:three, :four] }
        expect(type.instances.map(&:name)).to eq(["one", "two", "three", "four"])
      end

      it "should not return instances from unsuitable providers" do
        type.provide(:fake1, :parent => :default) do
          @names = [:three, :four]
          confine :exists => "/no/such/file"
        end

        expect(type.instances.map(&:name)).to eq(["one", "two"])
      end
    end
  end


  describe "::ensurable?" do
    before :each do
      class TestEnsurableType < Puppet::Type
        def exists?; end
        def create; end
        def destroy; end
      end
    end

    it "is true if the class has exists?, create, and destroy methods defined" do
      expect(TestEnsurableType).to be_ensurable
    end

    it "is false if exists? is not defined" do
      TestEnsurableType.class_eval { remove_method(:exists?) }
      expect(TestEnsurableType).not_to be_ensurable
    end

    it "is false if create is not defined" do
      TestEnsurableType.class_eval { remove_method(:create) }
      expect(TestEnsurableType).not_to be_ensurable
    end

    it "is false if destroy is not defined" do
      TestEnsurableType.class_eval { remove_method(:destroy) }
      expect(TestEnsurableType).not_to be_ensurable
    end
  end
end

describe Puppet::Type::RelationshipMetaparam do
  include PuppetSpec::Files

  it "should be a subclass of Puppet::Parameter" do
    expect(Puppet::Type::RelationshipMetaparam.superclass).to equal(Puppet::Parameter)
  end

  it "should be able to produce a list of subclasses" do
    expect(Puppet::Type::RelationshipMetaparam).to respond_to(:subclasses)
  end

  describe "when munging relationships" do
    before do
      @path = File.expand_path('/foo')
      @resource = Puppet::Type.type(:file).new :name => @path
      @metaparam = Puppet::Type.metaparamclass(:require).new :resource => @resource
    end

    it "should accept Puppet::Resource instances" do
      ref = Puppet::Resource.new(:file, @path)
      expect(@metaparam.munge(ref)[0]).to equal(ref)
    end

    it "should turn any string into a Puppet::Resource" do
      expect(@metaparam.munge("File[/ref]")[0]).to be_instance_of(Puppet::Resource)
    end
  end

  it "should be able to validate relationships" do
    expect(Puppet::Type.metaparamclass(:require).new(:resource => double("resource"))).to respond_to(:validate_relationship)
  end

  describe 'if any specified resource is not in the catalog' do
    let(:catalog) { double('catalog') }

    let(:resource) do
      double(
        'resource',
        :catalog => catalog,
        :ref     => 'resource',
        :line=   => nil,
        :line    => nil,
        :file=   => nil,
        :file    => nil
      )
    end

    let(:param) { Puppet::Type.metaparamclass(:require).new(:resource => resource, :value => %w{Foo[bar] Class[test]}) }

    before do
      expect(catalog).to receive(:resource).with("Foo[bar]").and_return("something")
      expect(catalog).to receive(:resource).with("Class[Test]").and_return(nil)
    end

    describe "and the resource doesn't have a file or line number" do
      it "raises an error" do
        expect { param.validate_relationship }.to raise_error do |error|
          expect(error).to be_a Puppet::ResourceError
          expect(error.message).to match %r[Class\[Test\]]
        end
      end
    end

    describe "and the resource has a file or line number" do
      before do
        allow(resource).to receive(:line).and_return('42')
        allow(resource).to receive(:file).and_return('/hitchhikers/guide/to/the/galaxy')
      end

      it "raises an error with context" do
        expect { param.validate_relationship }.to raise_error do |error|
          expect(error).to be_a Puppet::ResourceError
          expect(error.message).to match %r[Class\[Test\]]
          expect(error.message).to match %r[\(file: /hitchhikers/guide/to/the/galaxy, line: 42\)]
        end
      end
    end
  end
end

describe Puppet::Type.metaparamclass(:audit) do
  include PuppetSpec::Files

  before do
    @resource = Puppet::Type.type(:file).new :path => make_absolute('/foo')
  end

  it "should default to being nil" do
    expect(@resource[:audit]).to be_nil
  end

  it "should specify all possible properties when asked to audit all properties" do
    @resource[:audit] = :all

    list = @resource.class.properties.collect { |p| p.name }
    expect(@resource[:audit]).to eq(list)
  end

  it "should accept the string 'all' to specify auditing all possible properties" do
    @resource[:audit] = 'all'

    list = @resource.class.properties.collect { |p| p.name }
    expect(@resource[:audit]).to eq(list)
  end

  it "should fail if asked to audit an invalid property" do
    expect { @resource[:audit] = :foobar }.to raise_error(Puppet::Error)
  end

  it "should create an attribute instance for each auditable property" do
    @resource[:audit] = :mode
    expect(@resource.parameter(:mode)).not_to be_nil
  end

  it "should accept properties specified as a string" do
    @resource[:audit] = "mode"
    expect(@resource.parameter(:mode)).not_to be_nil
  end

  it "should not create attribute instances for parameters, only properties" do
    @resource[:audit] = :noop
    expect(@resource.parameter(:noop)).to be_nil
  end

  describe "when generating the uniqueness key" do
    it "should include all of the key_attributes in alphabetical order by attribute name" do
      allow(Puppet::Type.type(:file)).to receive(:key_attributes).and_return([:path, :mode, :owner])
      allow(Puppet::Type.type(:file)).to receive(:title_patterns).and_return(
        [ [ /(.*)/, [ [:path, lambda{|x| x} ] ] ] ]
      )
      myfile = make_absolute('/my/file')
      res = Puppet::Type.type(:file).new( :title => myfile, :path => myfile, :owner => 'root', :content => 'hello' )
      expect(res.uniqueness_key).to eq([ nil, 'root', myfile])
    end
  end

  context "type attribute bracket methods" do
    after :each do Puppet::Type.rmtype(:attributes)     end
    let   :type do
      Puppet::Type.newtype(:attributes) do
        newparam(:name) {}
      end
    end

    it "should work with parameters" do
      type.newparam(:param) {}
      instance = type.new(:name => 'test')

      expect { instance[:param] = true }.to_not raise_error
      expect { instance["param"] = true }.to_not raise_error
      expect(instance[:param]).to eq(true)
      expect(instance["param"]).to eq(true)
    end

    it "should work with meta-parameters" do
      instance = type.new(:name => 'test')

      expect { instance[:noop] = true }.to_not raise_error
      expect { instance["noop"] = true }.to_not raise_error
      expect(instance[:noop]).to eq(true)
      expect(instance["noop"]).to eq(true)
    end

    it "should work with properties" do
      type.newproperty(:property) {}
      instance = type.new(:name => 'test')

      expect { instance[:property] = true }.to_not raise_error
      expect { instance["property"] = true }.to_not raise_error
      expect(instance.property(:property)).to be
      expect(instance.should(:property)).to be_truthy
    end

    it "should handle proprieties correctly" do
      # Order of assignment is significant in this test.
      [:one, :two, :three].each {|prop| type.newproperty(prop) {} }
      instance = type.new(:name => "test")

      instance[:one] = "boo"
      one = instance.property(:one)
      expect(instance.properties).to eq [one]

      instance[:three] = "rah"
      three = instance.property(:three)
      expect(instance.properties).to eq [one, three]

      instance[:two] = "whee"
      two = instance.property(:two)
      expect(instance.properties).to eq [one, two, three]
    end

    it "newattr should handle required features correctly" do
      Puppet::Util::Log.level = :debug

      type.feature :feature1, "one"
      type.feature :feature2, "two"

      type.newproperty(:none) {}
      type.newproperty(:one, :required_features => :feature1) {}
      type.newproperty(:two, :required_features => [:feature1, :feature2]) {}

      nope  = type.provide(:nope)  {}
      maybe = type.provide(:maybe) { has_features :feature1 }
      yep   = type.provide(:yep)   { has_features :feature1, :feature2 }

      [nope, maybe, yep].each_with_index do |provider, i|
        rsrc = type.new(:provider => provider.name, :name => "test#{i}",
                        :none => "a", :one => "b", :two => "c")

        expect(rsrc.should(:none)).to be

        if provider.declared_feature? :feature1
          expect(rsrc.should(:one)).to be
        else
          expect(rsrc.should(:one)).to_not be
          expect(@logs.find {|l| l.message =~ /not managing attribute one/ }).to be
        end

        if provider.declared_feature? :feature2
          expect(rsrc.should(:two)).to be
        else
          expect(rsrc.should(:two)).to_not be
          expect(@logs.find {|l| l.message =~ /not managing attribute two/ }).to be
        end
      end
    end
  end
end
