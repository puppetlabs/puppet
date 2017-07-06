require 'puppet/pops'

module FactoryRspecHelper
  def literal(x)
    Puppet::Pops::Model::Factory.literal(x)
  end

  def block(*args)
    Puppet::Pops::Model::Factory.block(*args)
  end

  def var(x)
    Puppet::Pops::Model::Factory.var(x)
  end

  def fqn(x)
    Puppet::Pops::Model::Factory.fqn(x)
  end

  def string(*args)
    Puppet::Pops::Model::Factory.string(*args)
  end

  def text(x)
    Puppet::Pops::Model::Factory.text(x)
  end

  def minus(x)
    Puppet::Pops::Model::Factory.minus(x)
  end

  def IF(test, then_expr, else_expr=nil)
    Puppet::Pops::Model::Factory.IF(test, then_expr, else_expr)
  end

  def UNLESS(test, then_expr, else_expr=nil)
    Puppet::Pops::Model::Factory.UNLESS(test, then_expr, else_expr)
  end

  def CASE(test, *options)
    Puppet::Pops::Model::Factory.CASE(test, *options)
  end

  def WHEN(values, block)
    Puppet::Pops::Model::Factory.WHEN(values, block)
  end

  def method_missing(method, *args, &block)
    if Puppet::Pops::Model::Factory.respond_to? method
      Puppet::Pops::Model::Factory.send(method, *args, &block)
    else
      super
    end
  end

  # i.e. Selector Entry 1 => 'hello'
  def MAP(match, value)
    Puppet::Pops::Model::Factory.MAP(match, value)
  end

  def dump(x)
    Puppet::Pops::Model::ModelTreeDumper.new.dump(x)
  end

  def unindent x
    (x.gsub /^#{x[/\A\s*/]}/, '').chomp
  end
  factory ||= Puppet::Pops::Model::Factory
end
