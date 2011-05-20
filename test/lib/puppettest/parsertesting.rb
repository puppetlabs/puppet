require 'puppettest'
require 'puppet/rails'

module PuppetTest::ParserTesting
  include PuppetTest
  AST = Puppet::Parser::AST

  Compiler = Puppet::Parser::Compiler

  # A fake class that we can use for testing evaluation.
  class FakeAST
    attr_writer :evaluate

    def evaluated?
      @evaluated
    end

    def evaluate(*args)
      @evaluated = true
      @evaluate
    end

    def initialize(val = nil)
      @evaluate = val if val
    end

    def reset
      @evaluated = nil
    end

    def safeevaluate(*args)
      evaluate
    end

    def evaluate_match(othervalue, scope, options={})
      value = evaluate
      othervalue == value
    end
  end

  def astarray(*args)
    AST::ASTArray.new(
      :children => args
    )
  end

  def mkcompiler(parser = nil)
    node = mknode
    Compiler.new(node)
  end

  def mknode(name = nil)
    require 'puppet/node'
    Puppet::Node.new(name || "nodename")
  end

  def mkparser
    Puppet::Node::Environment.clear
    Puppet::Parser::Parser.new(Puppet::Node::Environment.new)
  end

  def mkscope(hash = {})
    parser ||= mkparser
    compiler ||= mkcompiler
    compiler.topscope.source = (parser.find_hostclass("", "") || parser.newclass(""))

    raise "Could not find source for scope" unless compiler.topscope.source
    # Make the 'main' stuff
    compiler.send(:evaluate_main)
    compiler.topscope
  end

  def classobj(name, hash = {})
    hash[:file] ||= __FILE__
    hash[:line] ||= __LINE__
    hash[:type] ||= name
    AST::HostClass.new(hash)
  end

  def tagobj(*names)
    args = {}
    newnames = names.collect do |name|
      if name.is_a? AST
        name
      else
        nameobj(name)
      end
    end
    args[:type] = astarray(*newnames)
    assert_nothing_raised("Could not create tag #{names.inspect}") {
      return AST::Tag.new(args)
    }
  end

  def resourcedef(type, title, params)
    title = stringobj(title) unless title.is_a?(AST)
    instance = AST::ResourceInstance.new(:title => title, :parameters => resourceparams(params))
    assert_nothing_raised("Could not create #{type} #{title}") {

      return AST::Resource.new(

        :file => __FILE__,
        :line => __LINE__,
        :type => type,
        :instances => AST::ASTArray.new(:children => [instance])
      )
    }
  end

  def virt_resourcedef(*args)
    res = resourcedef(*args)
    res.virtual = true
    res
  end

  def resourceoverride(type, title, params)
    assert_nothing_raised("Could not create #{type} #{name}") {

      return AST::ResourceOverride.new(

        :file => __FILE__,
        :line => __LINE__,
        :object => resourceref(type, title),
        :parameters => resourceparams(params)
      )
    }
  end

  def resourceref(type, title)
    assert_nothing_raised("Could not create #{type} #{title}") {

      return AST::ResourceReference.new(

        :file => __FILE__,
        :line => __LINE__,
        :type => type,

        :title => stringobj(title)
      )
    }
  end

  def fileobj(path, hash = {"owner" => "root"})
    assert_nothing_raised("Could not create file #{path}") {
      return resourcedef("file", path, hash)
    }
  end

  def nameobj(name)
    assert_nothing_raised("Could not create name #{name}") {

      return AST::Name.new(

        :file => tempfile,

        :line => rand(100),
        :value => name
          )
    }
  end

  def typeobj(name)
    assert_nothing_raised("Could not create type #{name}") {

      return AST::Type.new(

        :file => tempfile,

        :line => rand(100),
        :value => name
          )
    }
  end

  def nodedef(name)
    assert_nothing_raised("Could not create node #{name}") {

      return AST::NodeDef.new(

        :file => tempfile,

        :line => rand(100),
        :names => nameobj(name),

          :code => AST::ASTArray.new(

            :children => [
              varobj("#{name}var", "#{name}value"),

              fileobj("/#{name}")
          ]
        )
      )
    }
  end

  def resourceparams(hash)
    assert_nothing_raised("Could not create resource instance") {
      params = hash.collect { |param, value|
      resourceparam(param, value)
    }

      return AST::ASTArray.new(

        :file => tempfile,

        :line => rand(100),
        :children => params
          )
    }
  end

  def resourceparam(param, value)
    # Allow them to pass non-strings in
    value = stringobj(value) if value.is_a?(String)
    assert_nothing_raised("Could not create param #{param}") {

      return AST::ResourceParam.new(

        :file => tempfile,

        :line => rand(100),
        :param => param,
        :value => value
          )
    }
  end

  def stringobj(value)

    AST::String.new(

      :file => tempfile,

      :line => rand(100),
      :value => value
        )
  end

  def varobj(name, value)
    value = stringobj(value) unless value.is_a? AST
    assert_nothing_raised("Could not create #{name} code") {

      return AST::VarDef.new(

        :file => tempfile,

        :line => rand(100),
        :name => nameobj(name),
        :value => value
          )
    }
  end

  def varref(name)
    assert_nothing_raised("Could not create #{name} variable") {

      return AST::Variable.new(

        :file => __FILE__,
        :line => __LINE__,

        :value => name
          )
    }
  end

  def argobj(name, value)
    assert_nothing_raised("Could not create #{name} compargument") {
      return AST::CompArgument.new(
        :children => [nameobj(name), stringobj(value)]
          )
    }
  end

  def defaultobj(type, params)
    pary = []
    params.each { |p,v|

      pary << AST::ResourceParam.new(

        :file => __FILE__,
        :line => __LINE__,
        :param => p,

        :value => stringobj(v)
          )
    }

      past = AST::ASTArray.new(

        :file => __FILE__,
        :line => __LINE__,

        :children => pary
          )

    assert_nothing_raised("Could not create defaults for #{type}") {

      return AST::ResourceDefaults.new(

        :file => __FILE__,
        :line => __LINE__,
        :type => type,

        :parameters => past
      )
    }
  end

  def taggedobj(name, ftype = :statement)
    functionobj("tagged", name, ftype)
  end

  def functionobj(function, name, ftype = :statement)
    func = nil
    assert_nothing_raised do

      func = Puppet::Parser::AST::Function.new(

        :name => function,
        :ftype => ftype,

        :arguments => AST::ASTArray.new(
          :children => [nameobj(name)]
        )
      )
    end

    func
  end

  # This assumes no nodes
  def assert_creates(manifest, *files)
    oldmanifest = Puppet[:manifest]
    Puppet[:manifest] = manifest

    catalog = Puppet::Parser::Compiler.new(mknode).compile.to_ral
    catalog.apply

    files.each do |file|
      assert(FileTest.exists?(file), "Did not create #{file}")
    end
  ensure
    Puppet[:manifest] = oldmanifest
  end

  def mk_transobject(file = "/etc/passwd")
    obj = nil
    assert_nothing_raised {
      obj = Puppet::TransObject.new("file", file)
      obj["owner"] = "root"
      obj["mode"] = "644"
    }

    obj
  end

  def mk_transbucket(*resources)
    bucket = nil
    assert_nothing_raised {
      bucket = Puppet::TransBucket.new
      bucket.name = "yayname"
      bucket.type = "yaytype"
    }

    resources.each { |o| bucket << o }

    bucket
  end

  # Make a tree of resources, yielding if desired
  def mk_transtree(depth = 4, width = 2)
    top = nil
    assert_nothing_raised {
      top = Puppet::TransBucket.new
      top.name = "top"
      top.type = "bucket"
    }

    bucket = top

    file = tempfile
    depth.times do |i|
      resources = []
      width.times do |j|
        path = tempfile + i.to_s
        obj = Puppet::TransObject.new("file", path)
        obj["owner"] = "root"
        obj["mode"] = "644"

        # Yield, if they want
        yield(obj, i, j) if block_given?

        resources << obj
      end

      newbucket = mk_transbucket(*resources)

      bucket.push newbucket
      bucket = newbucket
    end

    top
  end

  # Take a list of AST resources, evaluate them, and return the results
  def assert_evaluate(children)
    top = nil
    assert_nothing_raised("Could not create top object") {
      top = AST::ASTArray.new(
        :children => children
      )
    }

    trans = nil
    scope = nil
    assert_nothing_raised {
      scope = Puppet::Parser::Scope.new
      trans = scope.evaluate(:ast => top)
    }

    trans
  end
end
