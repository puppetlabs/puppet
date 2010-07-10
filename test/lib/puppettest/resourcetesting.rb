module PuppetTest::ResourceTesting
  Parser = Puppet::Parser
  AST = Puppet::Parser::AST

  def mkevaltest(parser = nil)
    parser ||= mkparser

          @parser.newdefine(
        "evaltest",
        
      :arguments => [%w{one}, ["two", stringobj("755")]],

            :code => resourcedef(
        "file", "/tmp",
        
        "owner" => varref("one"), "mode" => varref("two"))
    )
  end

  def mkresource(args = {})
    args[:source] ||= "source"
    args[:scope] ||= mkscope

    type = args[:type] || "resource"
    title = args[:title] || "testing"
    args.delete(:type)
    args.delete(:title)
    {:source => "source", :scope => "scope"}.each do |param, value|
      args[param] ||= value
    end

    params = args[:parameters] || {:one => "yay", :three => "rah"}
    if args[:parameters] == :none
      args.delete(:parameters)
    else
      args[:parameters] = paramify args[:source], params
    end

    Parser::Resource.new(type, title, args)
  end

  def param(name, value, source)
    Parser::Resource::Param.new(:name => name, :value => value, :source => source)
  end

  def paramify(source, hash)
    hash.collect do |name, value|
      Parser::Resource::Param.new(
        :name => name, :value => value, :source => source
      )
    end
  end
end

