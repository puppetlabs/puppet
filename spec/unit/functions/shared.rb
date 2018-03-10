shared_examples_for 'all functions transforming relative to absolute names' do |func_name|
  before(:each) do
    # mock that the class 'myclass' exists which are needed for the 'require' functions
    # as it checks the existence of the required class
    @klass = stub 'class', :name => "myclass"
    @scope.environment.known_resource_types.stubs(:find_hostclass).returns(@klass)
    @resource = Puppet::Parser::Resource.new(:file, "/my/file", :scope => @scope, :source => "source")
    @scope.stubs(:resource).returns @resource
  end

  it 'accepts a Class[name] type' do
    @scope.compiler.expects(:evaluate_classes).with(["::myclass"], @scope, false)
    @scope.call_function(func_name, [Puppet::Pops::Types::TypeFactory.host_class('myclass')])
  end

  it 'accepts a Resource[class, name] type' do
    @scope.compiler.expects(:evaluate_classes).with(["::myclass"], @scope, false)
    @scope.call_function(func_name, [Puppet::Pops::Types::TypeFactory.resource('class', 'myclass')])
  end

  it 'raises and error for unspecific Class' do
    expect {
      @scope.call_function(func_name, [Puppet::Pops::Types::TypeFactory.host_class()])
    }.to raise_error(ArgumentError, /Cannot use an unspecific Class\[\] Type/)
  end

  it 'raises and error for Resource that is not of class type' do
    expect {
      @scope.call_function(func_name, [Puppet::Pops::Types::TypeFactory.resource('file')])
    }.to raise_error(ArgumentError, /Cannot use a Resource\[File\] where a Resource\['class', name\] is expected/)
  end

  it 'raises and error for Resource that is unspecific' do
    expect {
      @scope.call_function(func_name, [Puppet::Pops::Types::TypeFactory.resource()])
    }.to raise_error(ArgumentError, /Cannot use an unspecific Resource\[\] where a Resource\['class', name\] is expected/)
  end

  it 'raises and error for Resource[class] that is unspecific' do
    expect {
      @scope.call_function(func_name, [Puppet::Pops::Types::TypeFactory.resource('class')])
    }.to raise_error(ArgumentError, /Cannot use an unspecific Resource\['class'\] where a Resource\['class', name\] is expected/)
  end

end

shared_examples_for 'an inclusion function, regardless of the type of class reference,' do |function|

    it "and #{function} a class absolutely, even when a relative namespaced class of the same name is present" do
      catalog = compile_to_catalog(<<-MANIFEST)
        class foo {
          class bar { }
          #{function} bar
        }
        class bar { }
        include foo
      MANIFEST
      expect(catalog.classes).to include('foo','bar')
    end

    it "and #{function} a class absolutely by Class['type'] reference" do
      catalog = compile_to_catalog(<<-MANIFEST)
        class foo {
          class bar { }
          #{function} Class['bar'] 
        }
        class bar { }
        include foo
      MANIFEST
      expect(catalog.classes).to include('foo','bar')
    end

    it "and #{function} a class absolutely by Resource['type','title'] reference" do
      catalog = compile_to_catalog(<<-MANIFEST)
        class foo {
          class bar { }
          #{function} Resource['class','bar'] 
        }
        class bar { }
        include foo
      MANIFEST
      expect(catalog.classes).to include('foo','bar')
    end

end

shared_examples_for 'an inclusion function, when --tasks is on,' do |function|
  it "is not available when --tasks is on" do
    Puppet[:tasks] = true
    expect do
      compile_to_catalog(<<-MANIFEST)
        #{function}(bar)
      MANIFEST
    end.to raise_error(Puppet::ParseError, /is only available when compiling a catalog/)
  end
end

