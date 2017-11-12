#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'

describe "the 'defined' function" do
  after(:all) { Puppet::Pops::Loaders.clear }

  # This loads the function once and makes it easy to call it
  # It does not matter that it is not bound to the env used later since the function
  # looks up everything via the scope that is given to it.
  # The individual tests needs to have a fresh env/catalog set up
  #
  let(:loaders) { Puppet::Pops::Loaders.new(Puppet::Node::Environment.create(:testing, [])) }
  let(:func) { loaders.puppet_system_loader.load(:function, 'defined') }

  before :each do
    # A fresh environment is needed for each test since tests creates types and resources
    environment = Puppet::Node::Environment.create(:testing, [])
    @node = Puppet::Node.new('yaynode', :environment => environment)
    @known_resource_types = environment.known_resource_types
    @compiler = Puppet::Parser::Compiler.new(@node)
    @scope = Puppet::Parser::Scope.new(@compiler)
  end

  def newclass(name)
    @known_resource_types.add Puppet::Resource::Type.new(:hostclass, name)
  end

  def newdefine(name)
    @known_resource_types.add Puppet::Resource::Type.new(:definition, name)
  end

  def newresource(type, title)
    resource = Puppet::Resource.new(type, title)
    @compiler.add_resource(@scope, resource)
    resource
  end

  #--- CLASS
  #
  context 'can determine if a class' do
    context 'is defined' do

      it 'by using the class name in string form' do
        newclass 'yayness'
        expect(func.call(@scope, 'yayness')).to be_truthy
      end

      it 'by using a Type[Class[name]] type reference' do
        name = 'yayness'
        newclass name
        class_type = Puppet::Pops::Types::TypeFactory.host_class(name)
        type_type = Puppet::Pops::Types::TypeFactory.type_type(class_type)
        expect(func.call(@scope, type_type)).to be_truthy
      end
    end

    context 'is not defined' do
      it 'by using the class name in string form' do
        expect(func.call(@scope, 'yayness')).to be_falsey
      end

      it 'even if there is a define, by using a Type[Class[name]] type reference' do
        name = 'yayness'
        newdefine name
        class_type = Puppet::Pops::Types::TypeFactory.host_class(name)
        type_type = Puppet::Pops::Types::TypeFactory.type_type(class_type)
        expect(func.call(@scope, type_type)).to be_falsey
      end
    end

    context 'is defined and realized' do
      it 'by using a Class[name] reference' do
        name = 'cowabunga'
        newclass name
        newresource(:class, name)
        class_type = Puppet::Pops::Types::TypeFactory.host_class(name)
        expect(func.call(@scope, class_type)).to be_truthy
      end
    end

    context 'is not realized' do
      it '(although defined) by using a Class[name] reference' do
        name = 'cowabunga'
        newclass name
        class_type = Puppet::Pops::Types::TypeFactory.host_class(name)
        expect(func.call(@scope, class_type)).to be_falsey
      end

      it '(and not defined) by using a Class[name] reference' do
        name = 'cowabunga'
        class_type = Puppet::Pops::Types::TypeFactory.host_class(name)
        expect(func.call(@scope, class_type)).to be_falsey
      end
    end
  end

  #---RESOURCE TYPE
  #
  context 'can determine if a resource type' do
    context 'is defined' do

      it 'by using the type name (of a built in type) in string form' do
        expect(func.call(@scope, 'file')).to be_truthy
      end

      it 'by using the type name (of a resource type) in string form' do
        newdefine 'yayness'
        expect(func.call(@scope, 'yayness')).to be_truthy
      end

      it 'by using a File type reference (built in type)' do
        resource_type = Puppet::Pops::Types::TypeFactory.resource('file')
        type_type = Puppet::Pops::Types::TypeFactory.type_type(resource_type)
        expect(func.call(@scope, type_type)).to be_truthy
      end

      it 'by using a Type[File] type reference' do
        resource_type = Puppet::Pops::Types::TypeFactory.resource('file')
        type_type = Puppet::Pops::Types::TypeFactory.type_type(resource_type)
        expect(func.call(@scope, type_type)).to be_truthy
      end

      it 'by using a Resource[T] type reference (defined type)' do
        name = 'yayness'
        newdefine name
        resource_type = Puppet::Pops::Types::TypeFactory.resource(name)
        expect(func.call(@scope, resource_type)).to be_truthy
      end

      it 'by using a Type[Resource[T]] type reference (defined type)' do
        name = 'yayness'
        newdefine name
        resource_type = Puppet::Pops::Types::TypeFactory.resource(name)
        type_type = Puppet::Pops::Types::TypeFactory.type_type(resource_type)
        expect(func.call(@scope, type_type)).to be_truthy
      end
    end

    context 'is not defined' do
      it 'by using the resource name in string form' do
        expect(func.call(@scope, 'notatype')).to be_falsey
      end

      it 'even if there is a class with the same name, by using a Type[Resource[T]] type reference' do
        name = 'yayness'
        newclass name
        resource_type = Puppet::Pops::Types::TypeFactory.resource(name)
        type_type = Puppet::Pops::Types::TypeFactory.type_type(resource_type)
        expect(func.call(@scope, type_type)).to be_falsey
      end
    end

    context 'is defined and instance realized' do
      it 'by using a Resource[T, title] reference for a built in type' do
        type_name = 'file'
        title = '/tmp/myfile'
        newdefine type_name
        newresource(type_name, title)
        class_type = Puppet::Pops::Types::TypeFactory.resource(type_name, title)
        expect(func.call(@scope, class_type)).to be_truthy
      end

      it 'by using a Resource[T, title] reference for a defined type' do
        type_name = 'meme'
        title = 'cowabunga'
        newdefine type_name
        newresource(type_name, title)
        class_type = Puppet::Pops::Types::TypeFactory.resource(type_name, title)
        expect(func.call(@scope, class_type)).to be_truthy
      end
    end

    context 'is not realized' do
      it '(although defined) by using a Resource[T, title] reference or Type[Resource[T, title]] reference' do
        type_name = 'meme'
        title = 'cowabunga'
        newdefine type_name
        resource_type = Puppet::Pops::Types::TypeFactory.resource(type_name, title)
        expect(func.call(@scope, resource_type)).to be_falsey

        type_type = Puppet::Pops::Types::TypeFactory.type_type(resource_type)
        expect(func.call(@scope, type_type)).to be_falsey
      end

      it '(and not defined) by using a Resource[T, title] reference or Type[Resource[T, title]] reference' do
        type_name = 'meme'
        title = 'cowabunga'
        resource_type = Puppet::Pops::Types::TypeFactory.resource(type_name, title)
        expect(func.call(@scope, resource_type)).to be_falsey

        type_type = Puppet::Pops::Types::TypeFactory.type_type(resource_type)
        expect(func.call(@scope, type_type)).to be_falsey
      end
    end
  end

  #---VARIABLES
  #
  context 'can determine if a variable' do
    context 'is defined' do
      it 'by giving the variable in string form' do
        @scope['x'] = 'something'
        expect(func.call(@scope, '$x')).to be_truthy
      end

      it 'by giving a :: prefixed variable in string form' do
        @compiler.topscope['x'] = 'something'
        expect(func.call(@scope, '$::x')).to be_truthy
      end

      it 'by giving a numeric variable in string form (when there is a match scope)' do
        # with no match scope, there are no numeric variables defined
        expect(func.call(@scope, '$0')).to be_falsey
        expect(func.call(@scope, '$42')).to be_falsey
        pattern = Regexp.new('.*')
        @scope.new_match_scope(pattern.match('anything'))

        # with a match scope, all numeric variables are set (the match defines if they have a value or not, but they are defined)
        # even if their value is undef.
        expect(func.call(@scope, '$0')).to be_truthy
        expect(func.call(@scope, '$42')).to be_truthy
      end
    end

    context 'is undefined' do
      it 'by giving a :: prefixed or regular variable in string form' do
        expect(func.call(@scope, '$x')).to be_falsey
        expect(func.call(@scope, '$::x')).to be_falsey
      end
    end
  end

  context 'has any? semantics when given multiple arguments' do
    it 'and one of the names is a defined user defined type' do
      newdefine 'yayness'
      expect(func.call(@scope, 'meh', 'yayness', 'booness')).to be_truthy
    end

    it 'and one of the names is a built type' do
      expect(func.call(@scope, 'meh', 'file', 'booness')).to be_truthy
    end

    it 'and one of the names is a defined class' do
      newclass 'yayness'
      expect(func.call(@scope, 'meh', 'yayness', 'booness')).to be_truthy
    end

    it 'is true when at least one variable exists in scope' do
      @scope['x'] = 'something'
      expect(func.call(@scope, '$y', '$x', '$z')).to be_truthy
    end

    it 'is false when none of the names are defined' do
      expect(func.call(@scope, 'meh', 'yayness', 'booness')).to be_falsey
    end
  end

  it 'raises an argument error when asking if Resource type is defined' do
    resource_type = Puppet::Pops::Types::TypeFactory.resource
    expect { func.call(@scope, resource_type)}.to raise_error(ArgumentError, /reference to all.*type/)
  end

  it 'raises an argument error if you ask if Class is defined' do
    class_type = Puppet::Pops::Types::TypeFactory.host_class
    expect { func.call(@scope, class_type) }.to raise_error(ArgumentError, /reference to all.*class/)
  end

  it 'raises error if referencing undef' do
    expect{func.call(@scope, nil)}.to raise_error(ArgumentError, /'defined' parameter 'vals' expects a value of type String, Type\[CatalogEntry\], or Type\[Type\], got Undef/)
  end

  it 'raises error if referencing a number' do
    expect{func.call(@scope, 42)}.to raise_error(ArgumentError, /'defined' parameter 'vals' expects a value of type String, Type\[CatalogEntry\], or Type\[Type\], got Integer/)
  end

  it 'is false if referencing empty string' do
    expect(func.call(@scope, '')).to be_falsey
  end

  it "is true if referencing 'main'" do
    # mimic what compiler does with "main" in intial import
    newclass ''
    newresource :class, ''
    expect(func.call(@scope, 'main')).to be_truthy
  end

end
