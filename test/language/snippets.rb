#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../lib/puppettest')

require 'puppet'
require 'puppet/parser/parser'
require 'puppet/network/client'
require 'puppet/network/handler'
require 'puppettest'

class TestSnippets < Test::Unit::TestCase
  include PuppetTest

  def setup
    super
    @file = Puppet::Type.type(:file)
    Facter.stubs(:to_hash).returns({})
    Facter.stubs(:value).returns("whatever")
  end

  def self.snippetdir
    PuppetTest.datadir "snippets"
  end

  def assert_file(path, msg = nil)
    unless file = @catalog.resource(:file, path)
      msg ||= "Could not find file #{path}"
      raise msg
    end
  end

  def assert_not_file(path, msg = nil)
    if file = @catalog.resource(:file, path)
      msg ||= "File #{path} exists!"
      raise msg
    end
  end

  def assert_mode_equal(mode, path)
    if mode.is_a? Integer
      mode = mode.to_s(8)
    end
    unless file = @catalog.resource(:file, path)
      raise "Could not find file #{path}"
    end

    unless mode == file.should(:mode)
      raise "Mode for %s is incorrect: %o vs %o" % [path, mode, file.should(:mode)]
    end
  end

  def snippet(name)
    File.join(self.class.snippetdir, name)
  end

  def file2ast(file)
    parser = Puppet::Parser::Parser.new
    parser.file = file
    ast = parser.parse

    ast
  end

  def snippet2ast(text)
    parser = Puppet::Parser::Parser.new
    parser.string = text
    ast = parser.parse

    ast
  end

  def client
    args = {
      :Listen => false
    }
    Puppet::Network::Client.new(args)
  end

  def ast2scope(ast)
    scope = Puppet::Parser::Scope.new
    ast.evaluate(scope)

    scope
  end

  def scope2objs(scope)
    objs = scope.to_trans
  end

  def snippet2scope(snippet)
    ast = snippet2ast(snippet)
    scope = ast2scope(ast)
  end

  def snippet2objs(snippet)
    ast = snippet2ast(snippet)
    scope = ast2scope(ast)
    objs = scope2objs(scope)
  end

  def properties(type)
    properties = type.validproperties
  end

  def metaparams(type)
    mparams = []
    Puppet::Type.eachmetaparam { |param|
      mparams.push param
    }

    mparams
  end

  def params(type)
    params = []
    type.parameters.each { |name,property|
      params.push name
    }

    params
  end

  def randthing(thing,type)
    list = self.send(thing,type)
    list[rand(list.length)]
  end

  def randeach(type)
    [:properties, :metaparams, :parameters].collect { |thing|
      randthing(thing,type)
    }
  end

  @@snippets = {
    true => [
      %{File { mode => 755 }}
    ],
  }

  def disabled_test_defaults
    Puppet::Type.eachtype { |type|
      next if type.name == :puppet or type.name == :component

      rands = randeach(type)

      name = type.name.to_s.capitalize

      [0..1, 0..2].each { |range|
        params = rands[range]
        paramstr = params.collect { |param|
          "#{param} => fake"
        }.join(", ")

        str = "#{name} { #{paramstr} }"

        scope = nil
        assert_nothing_raised {
          scope = snippet2scope(str)
        }

        defaults = nil
        assert_nothing_raised {
          defaults = scope.lookupdefaults(name)
        }

        p defaults

        params.each { |param|
          puts "#{name} => '#{param}'"
          assert(defaults.include?(param))
        }
      }
    }
  end

  # this is here in case no tests get defined; otherwise we get a warning
  def test_nothing
  end

  def snippet_filecreate
    %w{a b c d}.each { |letter|
      path = "/tmp/create#{letter}test"
      assert_file(path)
      assert_mode_equal(0755, path) if %w{a b}.include?(letter)
    }
  end

  def snippet_simpledefaults
    path = "/tmp/defaulttest"
    assert_file(path)
    assert_mode_equal(0755, path)
  end

  def snippet_simpleselector
    files = %w{a b c d}.collect { |letter|
      path = "/tmp/snippetselect#{letter}test"
      assert_file(path)
      assert_mode_equal(0755, path)
    }
  end

  def snippet_classpathtest
    path = "/tmp/classtest"

    file = @catalog.resource(:file, path)
    assert(file, "did not create file #{path}")

    assert_equal( "/Stage[main]/Testing/Mytype[componentname]/File[/tmp/classtest]", file.path)
  end

  def snippet_argumentdefaults
    path1 = "/tmp/argumenttest1"
    path2 = "/tmp/argumenttest2"

    file1 = @catalog.resource(:file, path1)
    file2 = @catalog.resource(:file, path2)

    assert_file(path1)
    assert_mode_equal(0755, path1)

    assert_file(path2)
    assert_mode_equal(0644, path2)
  end

  def snippet_casestatement
    paths = %w{
      /tmp/existsfile
      /tmp/existsfile2
      /tmp/existsfile3
      /tmp/existsfile4
      /tmp/existsfile5
      /tmp/existsfile6
    }

    paths.each { |path|
      file = @catalog.resource(:file, path)
      assert(file, "File #{path} is missing")
      assert_mode_equal(0755, path)
    }
  end

  def snippet_implicititeration
    paths = %w{a b c d e f g h}.collect { |l| "/tmp/iteration#{l}test" }

    paths.each { |path|
      file = @catalog.resource(:file, path)
      assert_file(path)
      assert_mode_equal(0755, path)
    }
  end

  def snippet_multipleinstances
    paths = %w{a b c}.collect { |l| "/tmp/multipleinstances#{l}" }

    paths.each { |path|
      assert_file(path)
      assert_mode_equal(0755, path)

    }
  end

  def snippet_namevartest
    file = "/tmp/testfiletest"
    dir = "/tmp/testdirtest"
    assert_file(file)
    assert_file(dir)
    assert_equal(:directory, @catalog.resource(:file, dir).should(:ensure), "Directory is not set to be a directory")
  end

  def snippet_scopetest
    file = "/tmp/scopetest"
    assert_file(file)
    assert_mode_equal(0755, file)
  end

  def snippet_selectorvalues
    nums = %w{1 2 3 4 5 6 7}
    files = nums.collect { |n|
      "/tmp/selectorvalues#{n}"
    }

    files.each { |f|
      assert_file(f)
      assert_mode_equal(0755, f)
    }
  end

  def snippet_singleselector
    nums = %w{1 2 3}
    files = nums.collect { |n|
      "/tmp/singleselector#{n}"
    }

    files.each { |f|
      assert_file(f)
      assert_mode_equal(0755, f)
    }
  end

  def snippet_falsevalues
    file = "/tmp/falsevaluesfalse"
    assert_file(file)
  end

  def disabled_snippet_classargtest
    [1,2].each { |num|
      file = "/tmp/classargtest#{num}"
      assert_file(file)
      assert_mode_equal(0755, file)
    }
  end

  def snippet_classheirarchy
    [1,2,3].each { |num|
      file = "/tmp/classheir#{num}"
      assert_file(file)
      assert_mode_equal(0755, file)
    }
  end

  def snippet_singleary
    [1,2,3,4].each { |num|
      file = "/tmp/singleary#{num}"
      assert_file(file)
    }
  end

  def snippet_classincludes
    [1,2,3].each { |num|
      file = "/tmp/classincludes#{num}"
      assert_file(file)
      assert_mode_equal(0755, file)
    }
  end

  def snippet_componentmetaparams
    ["/tmp/component1", "/tmp/component2"].each { |file|
      assert_file(file)
    }
  end

  def snippet_aliastest
    %w{/tmp/aliastest /tmp/aliastest2 /tmp/aliastest3}.each { |file|
      assert_file(file)
    }
  end

  def snippet_singlequote
    {   1 => 'a $quote',
      2 => 'some "\yayness\"'
    }.each { |count, str|
      path = "/tmp/singlequote#{count}"
      assert_file(path)
      assert_equal(str, @catalog.resource(:file, path).parameter(:content).actual_content)
    }
  end

  # There's no way to actually retrieve the list of classes from the
  # transaction.
  def snippet_tag
  end

  # Make sure that set tags are correctly in place, yo.
  def snippet_tagged
    tags = {"testing" => true, "yayness" => false,
      "both" => false, "bothtrue" => true, "define" => true}

    tags.each do |tag, retval|
      assert_file("/tmp/tagged#{tag}#{retval.to_s}")
    end
  end

  def snippet_defineoverrides
    file = "/tmp/defineoverrides1"
    assert_file(file)
    assert_mode_equal(0755, file)
  end

  def snippet_deepclassheirarchy
    5.times { |i|
      i += 1
      file = "/tmp/deepclassheir#{i}"
      assert_file(file)
    }
  end

  def snippet_emptyclass
    # There's nothing to check other than that it works
  end

  def snippet_emptyexec
    assert(@catalog.resource(:exec, "touch /tmp/emptyexectest"), "Did not create exec")
  end

  def snippet_multisubs
    path = "/tmp/multisubtest"
    assert_file(path)
    file = @catalog.resource(:file, path)
    assert_equal("{md5}5fbef65269a99bddc2106251dd89b1dc", file.should(:content), "sub2 did not override content")
    assert_mode_equal(0755, path)
  end

  def snippet_collection
    assert_file("/tmp/colltest1")
    assert_nil(@catalog.resource(:file, "/tmp/colltest2"), "Incorrectly collected file")
  end

  def snippet_virtualresources
    %w{1 2 3 4}.each do |num|
      assert_file("/tmp/virtualtest#{num}")
    end
  end

  def snippet_componentrequire
    %w{1 2}.each do |num|

            assert_file(
        "/tmp/testing_component_requires#{num}",
        
        "#{num} does not exist")
    end
  end

  def snippet_realize_defined_types
    assert_file("/tmp/realize_defined_test1")
    assert_file("/tmp/realize_defined_test2")
  end

  def snippet_collection_within_virtual_definitions
    assert_file("/tmp/collection_within_virtual_definitions1_foo.txt")
    assert_file("/tmp/collection_within_virtual_definitions2_foo2.txt")
  end

  def snippet_fqparents
    assert_file("/tmp/fqparent1", "Did not make file from parent class")
    assert_file("/tmp/fqparent2", "Did not make file from subclass")
  end

  def snippet_fqdefinition
    assert_file("/tmp/fqdefinition", "Did not make file from fully-qualified definition")
  end

  def snippet_subclass_name_duplication
    assert_file("/tmp/subclass_name_duplication1", "Did not make first file from duplicate subclass names")
    assert_file("/tmp/subclass_name_duplication2", "Did not make second file from duplicate subclass names")
  end

  def snippet_funccomma
    assert_file("/tmp/funccomma1", "Did not make first file from trailing function comma")
    assert_file("/tmp/funccomma2", "Did not make second file from trailing function comma")
  end

  def snippet_arraytrailingcomma
    assert_file("/tmp/arraytrailingcomma1", "Did not make first file from array")
    assert_file("/tmp/arraytrailingcomma2", "Did not make second file from array")
  end

  def snippet_multipleclass
    assert_file("/tmp/multipleclassone", "one")
    assert_file("/tmp/multipleclasstwo", "two")
  end

  def snippet_multilinecomments
    assert_not_file("/tmp/multilinecomments","Did create a commented resource");
  end

  def snippet_collection_override
    path = "/tmp/collection"
    assert_file(path)
    assert_mode_equal(0600, path)
  end

  def snippet_ifexpression
    assert_file("/tmp/testiftest","if test");
  end

  def snippet_hash
    assert_file("/tmp/myhashfile1","hash test 1");
    assert_file("/tmp/myhashfile2","hash test 2");
    assert_file("/tmp/myhashfile3","hash test 3");
    assert_file("/tmp/myhashfile4","hash test 4");
  end

  # Iterate across each of the snippets and create a test.
  Dir.entries(snippetdir).sort.each { |file|
    next if file =~ /^\./


    mname = "snippet_" + file.sub(/\.pp$/, '')
    if self.method_defined?(mname)
      #eval("alias #{testname} #{mname}")
      testname = ("test_#{mname}").intern
      self.send(:define_method, testname) {
        Puppet[:manifest] = snippet(file)
        facts = {
          "hostname" => "testhost",
          "domain" => "domain.com",
          "ipaddress" => "127.0.0.1",
          "fqdn" => "testhost.domain.com"
        }

        node = Puppet::Node.new("testhost")
        node.merge(facts)

        catalog = nil
        assert_nothing_raised("Could not compile catalog") {
          catalog = Puppet::Resource::Catalog.indirection.find(node)
        }

        assert_nothing_raised("Could not convert catalog") {
          catalog = catalog.to_ral
        }

        @catalog = catalog
        assert_nothing_raised {
          self.send(mname)
        }
      }
      mname = mname.intern
    end
  }
end
