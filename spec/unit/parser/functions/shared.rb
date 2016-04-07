shared_examples_for 'all functions transforming relative to absolute names' do |func_method|

  it 'transforms relative names to absolute' do
    @scope.compiler.expects(:evaluate_classes).with(["::myclass"], @scope, false)
    @scope.send(func_method, ["myclass"])
  end

  it 'accepts a Class[name] type' do
    @scope.compiler.expects(:evaluate_classes).with(["::myclass"], @scope, false)
    @scope.send(func_method, [Puppet::Pops::Types::TypeFactory.host_class('myclass')])
  end

  it 'accepts a Resource[class, name] type' do
    @scope.compiler.expects(:evaluate_classes).with(["::myclass"], @scope, false)
    @scope.send(func_method, [Puppet::Pops::Types::TypeFactory.resource('class', 'myclass')])
  end

  it 'raises and error for unspecific Class' do
    expect {
      @scope.send(func_method, [Puppet::Pops::Types::TypeFactory.host_class()])
    }.to raise_error(ArgumentError, /Cannot use an unspecific Class\[\] Type/)
  end

  it 'raises and error for Resource that is not of class type' do
    expect {
      @scope.send(func_method, [Puppet::Pops::Types::TypeFactory.resource('file')])
    }.to raise_error(ArgumentError, /Cannot use a Resource\[File\] where a Resource\['class', name\] is expected/)
  end

  it 'raises and error for Resource that is unspecific' do
    expect {
      @scope.send(func_method, [Puppet::Pops::Types::TypeFactory.resource()])
    }.to raise_error(ArgumentError, /Cannot use an unspecific Resource\[\] where a Resource\['class', name\] is expected/)
  end

  it 'raises and error for Resource[class] that is unspecific' do
    expect {
      @scope.send(func_method, [Puppet::Pops::Types::TypeFactory.resource('class')])
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
