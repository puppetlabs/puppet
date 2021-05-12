require 'spec_helper'

describe 'Puppet::Util::AtFork' do
  EXPECTED_HANDLER_METHODS = [:prepare, :parent, :child]

  before :each do
    Puppet::Util.class_exec do
      remove_const(:AtFork) if defined?(Puppet::Util::AtFork)
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
        expect(Puppet::Util::Platform).to receive(:solaris?).and_return(true)
      end

      after :each do
        Object.class_exec do
          remove_const(:Fiddle) if const_defined?(:Fiddle)
        end
      end

      def stub_solaris_handler(stub_noop_too = false)
        allow(Puppet::Util::AtFork).to receive(:require_relative).with(anything) do |lib|
          if lib == 'at_fork/solaris'
            load 'puppet/util/at_fork/solaris.rb'
            true
          elsif stub_noop_too && lib == 'at_fork/noop'
            Puppet::Util::AtFork.class_exec do
              const_set(:Noop, Class.new)
            end
            true
          else
            false
          end
        end.and_return(true)

        unless stub_noop_too
          Object.class_exec do
            const_set(:Fiddle, Module.new do
              const_set(:TYPE_VOIDP, nil)
              const_set(:TYPE_VOID,  nil)
              const_set(:TYPE_INT,   nil)
              const_set(:DLError,    Class.new(StandardError))
              const_set(:Handle,     Class.new { def initialize(library = nil, flags = 0); end })
              const_set(:Function,   Class.new { def initialize(ptr, args, ret_type, abi = 0); end })
            end)
          end
        end

        allow(TOPLEVEL_BINDING.eval('self')).to receive(:require).with(anything) do |lib|
          if lib == 'fiddle'
            raise LoadError, 'no fiddle' if stub_noop_too
          else
            Kernel.require lib
          end
          true
        end.and_return(true)
      end

      it %q(should return the Solaris specific AtFork handler) do
        allow(Puppet::Util::AtFork).to receive(:require_relative).with(anything) do |lib|
          if lib == 'at_fork/solaris'
            Puppet::Util::AtFork.class_exec do
              const_set(:Solaris, Class.new)
            end
            true
          else
            false
          end
        end.and_return(true)
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
        expect(Fiddle::Handle).to receive(:new).with(/^libcontract.so.*/).and_raise(Fiddle::DLError, 'no such library')
        expect { load 'puppet/util/at_fork.rb' }.to raise_error(Fiddle::DLError, 'no such library')
      end

      it %q(should fail when libcontract doesn't define all the necessary functions) do
        stub_solaris_handler
        handle = double('Fiddle::Handle')
        expect(Fiddle::Handle).to receive(:new).with(/^libcontract.so.*/).and_return(handle)
        expect(handle).to receive(:[]).and_raise(Fiddle::DLError, 'no such method')
        expect { load 'puppet/util/at_fork.rb' }.to raise_error(Fiddle::DLError, 'no such method')
      end

      it %q(the returned Solaris specific handler should respond to the expected methods) do
        stub_solaris_handler
        handle = double('Fiddle::Handle')
        expect(Fiddle::Handle).to receive(:new).with(/^libcontract.so.*/).and_return(handle)
        allow(handle).to receive(:[]).and_return(nil)
        allow(Fiddle::Function).to receive(:new).and_return(Proc.new {})
        load 'puppet/util/at_fork.rb'
        expect(Puppet::Util::AtFork.get_handler.public_methods).to include(*EXPECTED_HANDLER_METHODS)
      end
    end

    context 'when NOT on Solaris' do
      before :each do
        expect(Puppet::Util::Platform).to receive(:solaris?).and_return(false)
      end

      def stub_noop_handler(namespace_only = false)
        allow(Puppet::Util::AtFork).to receive(:require_relative).with(anything) do |lib|
          if lib == 'at_fork/noop'
            if namespace_only
              Puppet::Util::AtFork.class_exec do
                const_set(:Noop, Class.new)
              end
            else
              load 'puppet/util/at_fork/noop.rb'
            end
            true
          else
            false
          end
        end.and_return(true)
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
