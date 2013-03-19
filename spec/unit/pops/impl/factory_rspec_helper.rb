require 'puppet/pops/api'
require 'puppet/pops/api/model/model'
require 'puppet/pops/impl/model/factory'
require 'puppet/pops/impl/model/model_tree_dumper'

module FactoryRspecHelper

  def literal(x)
    Puppet::Pops::Impl::Model::Factory.literal(x)
  end
  
  def block(*args)
    Puppet::Pops::Impl::Model::Factory.block(*args)
  end
  
  def var(x)
    Puppet::Pops::Impl::Model::Factory.var(x)
  end
  
  def fqn(x)
    Puppet::Pops::Impl::Model::Factory.fqn(x)
  end

  def string(*args)
    Puppet::Pops::Impl::Model::Factory.string(*args)
  end

  def text(x)
    Puppet::Pops::Impl::Model::Factory.text(x)
  end
  
  def minus(x)
    Puppet::Pops::Impl::Model::Factory.minus(x)
  end

  def IF(test, then_expr, else_expr=nil)
    Puppet::Pops::Impl::Model::Factory.IF(test, then_expr, else_expr)
  end

  def UNLESS(test, then_expr, else_expr=nil)
    Puppet::Pops::Impl::Model::Factory.UNLESS(test, then_expr, else_expr)
  end
  
  def CASE(test, *options)
    Puppet::Pops::Impl::Model::Factory.CASE(test, *options)
  end
  
  def WHEN(values, block)
    Puppet::Pops::Impl::Model::Factory.WHEN(values, block)
  end

  def respond_to? method
    if Puppet::Pops::Impl::Model::Factory.respond_to? method
      true
    else
      super
    end
  end

  def method_missing(method, *args, &block)
    if Puppet::Pops::Impl::Model::Factory.respond_to? method
      Puppet::Pops::Impl::Model::Factory.send(method, *args, &block) 
    else
      super
    end
  end
  
  # i.e. Selector Entry 1 => 'hello'
  def MAP(match, value)
    Puppet::Pops::Impl::Model::Factory.MAP(match, value)
  end

  def dump(x)
    Puppet::Pops::Impl::Model::ModelTreeDumper.new.dump(x)
  end
  def unindent x
    (x.gsub /^#{x[/\A\s*/]}/, '').chomp
  end
  factory ||= Puppet::Pops::Impl::Model::Factory
end