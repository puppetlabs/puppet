#! /usr/bin/env ruby
require 'spec_helper'

describe 'Puppet::Util::AtFork' do
  EXPECTED_HANDLER_METHODS = [:prepare, :parent, :child]

  before :each do
    Puppet::Util.class_exec do
      const_set(:AtFork, Module.new)
    end
  end

  after :each do
    Puppet::Util.class_exec do
      remove_const(:AtFork)
    end
  end

  describe '.get_handler' do
    context 'when on Solaris' do
      before :each do
        Facter.expects(:value).with(:operatingsystem).returns('Solaris')
      end

      after :each do
        Object.class_exec do
          remove_const(:Fiddle) if const_defined?(:Fiddle)
        end
      end

      def stub_solaris_handler(stub_noop_too = false)
        Puppet::Util::AtFork.stubs(:require).with() do |lib|
          if lib == 'puppet/util/at_fork/solaris'
            load lib + '.rb'
            true
          elsif stub_noop_too && lib == 'puppet/util/at_fork/noop'
            Puppet::Util::AtFork.class_exec do
              const_set(:Noop, Class.new)
            end
            true
          else
            false
          end
        end.returns(true)

        unless stub_noop_too
          Object.class_exec do
            const_set(:Fiddle, Module.new do
              const_set(:TYPE_VOIDP, nil)
              const_set(:TYPE_VOID,  nil)
              const_set(:TYPE_INT,   nil)
              const_set(:DLError,    Class.new(StandardError))
              const_set(:Handle,     Class.new)
              const_set(:Function,   Class.new)
            end)
          end
        end

        TOPLEVEL_BINDING.eval('self').stubs(:require).with() do |lib|
          if lib == 'fiddle'
            raise LoadError, 'no fiddle' if stub_noop_too
          else
            Kernel.require lib
          end
          true
        end.returns(true)
      end

      it %q(should return the Solaris specific AtFork handler) do
        Puppet::Util::AtFork.stubs(:require).with() do |lib|
          if lib == 'puppet/util/at_fork/solaris'
            Puppet::Util::AtFork.class_exec do
              const_set(:Solaris, Class.new)
            end
            true
          else
            false
          end
        end.returns(true)
        load 'puppet/util/at_fork.rb'
        expect(Puppet::Util::AtFork.get_handler.class).to eq(Puppet::Util::AtFork::Solaris)
      end

      it %q(should return the Noop handler when Fiddle could not be loaded) do
        stub_solaris_handler(true)
        load 'puppet/util/at_fork.rb'
        expect(Puppet::Util::AtFork.get_handler.class).to eq(Puppet::Util::AtFork::Noop)
      end

      it %q(should fail when libcontract cannot be loaded) do
        stub_solaris_handler
        Fiddle::Handle.expects(:new).with(regexp_matches(/^libcontract.so.*/)).raises(Fiddle::DLError, 'no such library')
        expect { load 'puppet/util/at_fork.rb' }.to raise_error(Fiddle::DLError, 'no such library')
      end

      it %q(should fail when libcontract doesn't define all the necessary functions) do
        stub_solaris_handler
        handle = stub('Fiddle::Handle')
        Fiddle::Handle.expects(:new).with(regexp_matches(/^libcontract.so.*/)).returns(handle)
        handle.expects(:[]).raises(Fiddle::DLError, 'no such method')
        expect { load 'puppet/util/at_fork.rb' }.to raise_error(Fiddle::DLError, 'no such method')
      end

      it %q(the returned Solaris specific handler should respond to the expected methods) do
        stub_solaris_handler
        handle = stub('Fiddle::Handle')
        Fiddle::Handle.expects(:new).with(regexp_matches(/^libcontract.so.*/)).returns(handle)
        handle.stubs(:[]).returns(nil)
        Fiddle::Function.stubs(:new).returns(Proc.new {})
        load 'puppet/util/at_fork.rb'
        expect(Puppet::Util::AtFork.get_handler.public_methods).to include(*EXPECTED_HANDLER_METHODS)
      end
    end

    context 'when NOT on Solaris' do
      before :each do
        Facter.expects(:value).with(:operatingsystem).returns(nil)
      end

      def stub_noop_handler(namespace_only = false)
        Puppet::Util::AtFork.stubs(:require).with() do |lib|
          if lib == 'puppet/util/at_fork/noop'
            if namespace_only
              Puppet::Util::AtFork.class_exec do
                const_set(:Noop, Class.new)
              end
            else
              load lib + '.rb'
            end
            true
          else
            false
          end
        end.returns(true)
      end

      it %q(should return the Noop AtFork handler) do
        stub_noop_handler(true)
        load 'puppet/util/at_fork.rb'
        expect(Puppet::Util::AtFork.get_handler.class).to eq(Puppet::Util::AtFork::Noop)
      end

      it %q(the returned Noop handler should respond to the expected methods) do
        stub_noop_handler
        load 'puppet/util/at_fork.rb'
        expect(Puppet::Util::AtFork.get_handler.public_methods).to include(*EXPECTED_HANDLER_METHODS)
      end
    end
  end
end
