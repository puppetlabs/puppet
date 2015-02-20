require 'spec_helper'
require 'puppet_spec/scope'
require 'puppet/pops'
require 'puppet/loaders'

describe 'when calling' do
  include PuppetSpec::Scope

  let(:scope) { create_test_scope_for_node('foo') }
  let(:loaders) { Puppet::Pops::Loaders.new(Puppet::Node::Environment.create(:testing, [])) }
  let(:loader) { loaders.puppet_system_loader }

  context 'hiera' do
    let(:hiera) { loader.load(:function, 'hiera') }

    it 'should require a key argument' do
      expect { hiera.call(scope, []) }.to raise_error(ArgumentError)
    end

    it 'should raise a useful error when nil is returned' do
      expect { hiera.call(scope, 'badkey') }.to raise_error(Puppet::ParseError, /Could not find data item badkey/)
    end

    it 'should use the priority resolution_type' do
      Hiera.any_instance.expects(:lookup).with { |*args| args[4].should be(:priority) }.returns('foo_result')
      expect(hiera.call(scope, 'key')).to eql('foo_result')
    end

    it 'should propagate optional default' do
      dflt = 'the_default'
      Hiera.any_instance.expects(:lookup).with { |*args| args[1].should be(dflt) }.returns('foo_result')
      expect(hiera.call(scope, 'key', dflt)).to eql('foo_result')
    end

    it 'should propagate optional override' do
      ovr = 'the_override'
      Hiera.any_instance.expects(:lookup).with { |*args| args[3].should be(ovr) }.returns('foo_result')
      expect(hiera.call(scope, 'key', nil, ovr)).to eql('foo_result')
    end

    it 'should use default block' do
      #expect(hiera.call(scope, 'foo', lambda_1(scope, loader) { |k| "default for key '#{k}'" })).to eql("default for key 'foo'")
      expect(hiera.call(scope, 'foo') { |k| "default for key '#{k}'" }).to eql("default for key 'foo'")
    end

    # Test disabled since it assumes that Yaml_backend returns nil when a key is not found and that this
    # triggers use of default. This changes in Hiera 2.0 so that the backend throws a :no_such_key exception.
    # Changing that here will invalidate tests using hiera stable.
    #
    # it 'should propagate optional override when combined with default block' do
    #   ovr = 'the_override'
    #   Hiera::Backend::Yaml_backend.any_instance.expects(:lookup).with { |*args| args[2].should be(ovr) }
    #   expect(hiera.call(scope, 'foo', ovr) { |k| "default for key '#{k}'" }).to eql("default for key 'foo'")
    # end
  end

  context 'hiera_array' do
    # noinspection RubyResolve
    let(:hiera_array) { loader.load(:function, 'hiera_array') }

    it 'should require a key argument' do
      expect { hiera_array.call(scope, []) }.to raise_error(ArgumentError)
    end

    it 'should raise a useful error when nil is returned' do
      expect { hiera_array.call(scope, 'badkey') }.to raise_error(Puppet::ParseError, /Could not find data item badkey/)
    end

    it 'should use the array resolution_type' do
      Hiera.any_instance.expects(:lookup).with { |*args| args[4].should be(:array) }.returns(%w[foo bar baz])
      expect(hiera_array.call(scope, 'key', {'key' => 'foo_result'})).to eql(%w[foo bar baz])
    end

    it 'should use default block' do
      expect(hiera_array.call(scope, 'foo') { |k| ['key', k] }).to eql(%w[key foo])
    end
  end

  context 'hiera_hash' do
    let(:hiera_hash) { loader.load(:function, 'hiera_hash') }

    it 'should require a key argument' do
      expect { hiera_hash.call(scope, []) }.to raise_error(ArgumentError)
    end

    it 'should raise a useful error when nil is returned' do
      expect { hiera_hash.call(scope, 'badkey') }.to raise_error(Puppet::ParseError, /Could not find data item badkey/)
    end

    it 'should use the hash resolution_type' do
      Hiera.any_instance.expects(:lookup).with { |*args| args[4].should be(:hash) }.returns({'foo' => 'result'})
      expect(hiera_hash.call(scope, 'key', {'key' => 'foo_result'})).to eql({'foo' => 'result'})
    end

    it 'should use default block' do
      expect(hiera_hash.call(scope, 'foo') { |k| {'key' => k} }).to eql({'key' => 'foo'})
    end
  end

  context 'hiera_include' do
    let(:hiera_include) { loader.load(:function, 'hiera_include') }

    it 'should require a key argument' do
      expect { hiera_include.call(scope, []) }.to raise_error(ArgumentError)
    end

    it 'should raise a useful error when nil is returned' do
      expect { hiera_include.call(scope, 'badkey') }.to raise_error(Puppet::ParseError, /Could not find data item badkey/)
    end

    it 'should use the array resolution_type' do
      Hiera.any_instance.expects(:lookup).with { |*args| args[4].should be(:array) }.returns(%w[foo bar baz])
      hiera_include.expects(:call_function).with('include', %w[foo bar baz])
      hiera_include.call(scope, 'key', {'key' => 'foo_result'})
    end

    it 'should not raise an error if the resulting hiera lookup returns an empty array' do
      Hiera.any_instance.expects(:lookup).returns []
      expect { hiera_include.call(scope, 'key') }.to_not raise_error
    end

    it 'should use default block' do
      hiera_include.expects(:call_function).with('include', %w[key foo])
      hiera_include.call(scope, 'foo') { |k| ['key', k] }
    end
  end
end
