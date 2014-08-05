require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'

describe "Puppet resource expressions" do
  include PuppetSpec::Compiler
  include Matchers::Resource

  def self.produces(expectations)
    expectations.each do |manifest, resources|
      it "evaluates #{manifest} to produce #{resources}" do
        catalog = compile_to_catalog(manifest)

        if resources.empty?
          base_resources = ["Class[Settings]", "Class[main]", "Stage[main]"]
          expect(catalog.resources.collect(&:ref) - base_resources).to eq([])
        else
          resources.each do |reference|
            if reference.is_a?(Array)
              matcher = have_resource(reference[0])
              reference[1].each do |name, value|
                matcher = matcher.with_parameter(name, value)
              end
            else
              matcher = have_resource(reference)
            end

            expect(catalog).to matcher
          end
        end
      end
    end
  end

  def self.fails(expectations)
    expectations.each do |manifest, pattern|
      it "fails to evaluate #{manifest} with message #{pattern}" do
        expect do
          compile_to_catalog(manifest)
        end.to raise_error(Puppet::Error, pattern)
      end
    end
  end

  describe "future parser" do
    before :each do
      Puppet[:parser] = 'future'
    end

    produces(
      "$a = notify; $b = example; $c = { message => hello }; @@$a { $b: * => $c } realize(Resource[$a, $b])" => [["Notify[example]", { :message => "hello" }]])

    context "resource titles" do
      produces(
        "notify { thing: }"                     => ["Notify[thing]"],
        "$x = thing notify { $x: }"             => ["Notify[thing]"],

        "notify { [thing]: }"                   => ["Notify[thing]"],
        "$x = [thing] notify { $x: }"           => ["Notify[thing]"],

        "notify { [[nested, array]]: }"         => ["Notify[nested]", "Notify[array]"],
        "$x = [[nested, array]] notify { $x: }" => ["Notify[nested]", "Notify[array]"],

        "notify { []: }"                        => [],
        "$x = [] notify { $x: }"                => [],

        "notify { default: }"                   => [], # nothing created because this is just a local default
        "$x = default notify { $x: }"           => [])

      fails(
        "notify { '': }"                         => /Empty string title/,
        "$x = '' notify { $x: }"                 => /Empty string title/,

        "notify { 1: }"                          => /Illegal title type.*Expected String, got Integer/,
        "$x = 1 notify { $x: }"                  => /Illegal title type.*Expected String, got Integer/,

        "notify { [1]: }"                        => /Illegal title type.*Expected String, got Integer/,
        "$x = [1] notify { $x: }"                => /Illegal title type.*Expected String, got Integer/,

        "notify { 3.0: }"                        => /Illegal title type.*Expected String, got Float/,
        "$x = 3.0 notify { $x: }"                => /Illegal title type.*Expected String, got Float/,

        "notify { [3.0]: }"                      => /Illegal title type.*Expected String, got Float/,
        "$x = [3.0] notify { $x: }"              => /Illegal title type.*Expected String, got Float/,

        "notify { true: }"                       => /Illegal title type.*Expected String, got Boolean/,
        "$x = true notify { $x: }"               => /Illegal title type.*Expected String, got Boolean/,

        "notify { [true]: }"                     => /Illegal title type.*Expected String, got Boolean/,
        "$x = [true] notify { $x: }"             => /Illegal title type.*Expected String, got Boolean/,

        "notify { [false]: }"                    => /Illegal title type.*Expected String, got Boolean/,
        "$x = [false] notify { $x: }"            => /Illegal title type.*Expected String, got Boolean/,

        "notify { undef: }"                      => /Missing title.*undef/,
        "$x = undef notify { $x: }"              => /Missing title.*undef/,

        "notify { [undef]: }"                    => /Missing title.*undef/,
        "$x = [undef] notify { $x: }"            => /Missing title.*undef/,

        "notify { {nested => hash}: }"           => /Illegal title type.*Expected String, got Hash/,
        "$x = {nested => hash} notify { $x: }"   => /Illegal title type.*Expected String, got Hash/,

        "notify { [{nested => hash}]: }"         => /Illegal title type.*Expected String, got Hash/,
        "$x = [{nested => hash}] notify { $x: }" => /Illegal title type.*Expected String, got Hash/,

        "notify { /regexp/: }"                   => /Illegal title type.*Expected String, got Regexp/,
        "$x = /regexp/ notify { $x: }"           => /Illegal title type.*Expected String, got Regexp/,

        "notify { [/regexp/]: }"                 => /Illegal title type.*Expected String, got Regexp/,
        "$x = [/regexp/] notify { $x: }"         => /Illegal title type.*Expected String, got Regexp/,

        "notify { [dupe, dupe]: }"               => /The title 'dupe' has already been used/,
        "notify { dupe:; dupe: }"                => /The title 'dupe' has already been used/,
        "notify { [dupe]:; dupe: }"              => /The title 'dupe' has already been used/,
        "notify { [default, default]:}"          => /The title 'default' has already been used/,
        "notify { default:; default:}"           => /The title 'default' has already been used/,
        "notify { [default]:; default:}"         => /The title 'default' has already been used/)
    end

    context "type names" do
      produces(
        "notify { testing: }"                  => ["Notify[testing]"],
        "$a = notify; $a { testing: }"         => ["Notify[testing]"],
        "'notify' { testing: }"                => ["Notify[testing]"],
        "sprintf('%s', 'notify') { testing: }" => ["Notify[testing]"],
        "$a = ify; \"not$a\" { testing: }"     => ["Notify[testing]"],

        "Notify { testing: }"           => ["Notify[testing]"],
        "Resource[Notify] { testing: }" => ["Notify[testing]"],
        "'Notify' { testing: }"         => ["Notify[testing]"],

        "class a { notify { testing: } } class { a: }"   => ["Notify[testing]"],
        "class a { notify { testing: } } Class { a: }"   => ["Notify[testing]"],
        "class a { notify { testing: } } 'class' { a: }" => ["Notify[testing]"],

        "define a::b { notify { testing: } } a::b { title: }" => ["Notify[testing]"],
        "define a::b { notify { testing: } } A::B { title: }" => ["Notify[testing]"],
        "define a::b { notify { testing: } } 'a::b' { title: }" => ["Notify[testing]"],
        "define a::b { notify { testing: } } Resource['a::b'] { title: }" => ["Notify[testing]"])

      fails(
        "'' { testing: }" => /Illegal type reference/,
        "1 { testing: }" => /Illegal Resource Type expression.*got Integer/,
        "3.0 { testing: }" => /Illegal Resource Type expression.*got Float/,
        "true { testing: }" => /Illegal Resource Type expression.*got Boolean/,
        "'not correct' { testing: }" => /Illegal type reference/,

        "Notify[hi] { testing: }" => /Illegal Resource Type expression.*got Notify\['hi'\]/,
        "[Notify, File] { testing: }" => /Illegal Resource Type expression.*got Array\[Type\[Resource\]\]/,

        "Does::Not::Exist { title: }" => /Invalid resource type does::not::exist/)
    end

    context "local defaults" do
      produces(
        "notify { example:;                     default: message => defaulted }" => [["Notify[example]", { :message => "defaulted" }]],
        "notify { example: message => specific; default: message => defaulted }" => [["Notify[example]", { :message => "specific" }]],
        "notify { example: message => undef;    default: message => defaulted }" => [["Notify[example]", { :message => nil }]],
        "notify { [example, other]: ;           default: message => defaulted }" => [["Notify[example]", { :message => "defaulted" }],
                                                                                     ["Notify[other]",   { :message => "defaulted" }]],
        "notify { [example, default]: message => set; other: }"                  => [["Notify[example]", { :message => "set" }],
                                                                                     ["Notify[other]",   { :message => "set" }]])
    end

    context "order of evaluation" do
      fails("notify { hi: message => value; bye: message => Notify[hi][message] }" => /Resource not found: Notify\['hi'\]/)

      produces("notify { hi: message => (notify { param: message => set }); bye: message => Notify[param][message] }" => ["Notify[hi]",
                                                                                                                          ["Notify[bye]", { :message => "set" }]])
      fails("notify { bye: message => Notify[param][message]; hi: message => (notify { param: message => set }) }" => /Resource not found: Notify\['param'\]/)
    end

    context "parameters" do
      produces(
        "notify { title: message => set }" => [["Notify[title]", { :message => "set" }]],
        "$x = set notify { title: message => $x }" => [["Notify[title]", { :message => "set" }]],

        "notify { title: *=> { message => set } }" => [["Notify[title]", { :message => "set" }]],
        "$x = { message => set } notify { title: * => $x }" => [["Notify[title]", { :message => "set" }]])

      fails(
        "notify { title: unknown => value }" => /Invalid parameter unknown/,

        #BUG
        "notify { title: * => { hash => value }, message => oops }" => /Invalid parameter hash/, # this really needs to be a better error message.
        "notify { title: message => oops, * => { hash => value } }" => /Syntax error/, # should this be a better error message?

        "notify { title: * => { unknown => value } }" => /Invalid parameter unknown/)
    end

    context "virtual" do
      produces(
        "@notify { example: }" => [],
        "@notify { example: } realize(Notify[example])" => ["Notify[example]"],
        "@notify { virtual: message => set } notify { real: message => Notify[virtual][message] }" => [["Notify[real]", { :message => "set" }]])
    end

    context "exported" do
      produces(
        "@@notify { example: }" => [],
        "@@notify { example: } realize(Notify[example])" => ["Notify[example]"],
        "@@notify { exported: message => set } notify { real: message => Notify[exported][message] }" => [["Notify[real]", { :message => "set" }]])
    end
  end

  describe "current parser" do
    before :each do
      Puppet[:parser] = 'current'
    end

    produces(
      "notify { thing: }"                     => ["Notify[thing]"],
      "$x = thing notify { $x: }"             => ["Notify[thing]"],

      "notify { [thing]: }"                   => ["Notify[thing]"],
      "$x = [thing] notify { $x: }"           => ["Notify[thing]"],

      "notify { [[nested, array]]: }"         => ["Notify[nested]", "Notify[array]"],
      "$x = [[nested, array]] notify { $x: }" => ["Notify[nested]", "Notify[array]"],

      # deprecate?
      "notify { 1: }"                         => ["Notify[1]"],
      "$x = 1 notify { $x: }"                 => ["Notify[1]"],

      # deprecate?
      "notify { [1]: }"                       => ["Notify[1]"],
      "$x = [1] notify { $x: }"               => ["Notify[1]"],

      # deprecate?
      "notify { 3.0: }"                       => ["Notify[3.0]"],
      "$x = 3.0 notify { $x: }"               => ["Notify[3.0]"],

      # deprecate?
      "notify { [3.0]: }"                     => ["Notify[3.0]"],
      "$x = [3.0] notify { $x: }"             => ["Notify[3.0]"])

    # :(
    fails(   "notify { true: }"         => /Syntax error/)
    produces("$x = true notify { $x: }" => ["Notify[true]"])

    # this makes no sense given the [false] case
    produces(
      "notify { [true]: }"         => ["Notify[true]"],
      "$x = [true] notify { $x: }" => ["Notify[true]"])

    # *sigh*
    fails(
      "notify { false: }"           => /Syntax error/,
      "$x = false notify { $x: }"   => /No title provided and :notify is not a valid resource reference/,

      "notify { [false]: }"         => /No title provided and :notify is not a valid resource reference/,
      "$x = [false] notify { $x: }" => /No title provided and :notify is not a valid resource reference/)

    # works for variable value, not for literal. deprecate?
    fails("notify { undef: }"         => /Syntax error/)
    produces(
      "$x = undef notify { $x: }" => ["Notify[undef]"],

      # deprecate?
      "notify { [undef]: }"         => ["Notify[undef]"],
      "$x = [undef] notify { $x: }" => ["Notify[undef]"])

    fails("notify { {nested => hash}: }" => /Syntax error/)
    #produces("$x = {nested => hash} notify { $x: }" => ["Notify[{nested => hash}]"]) #it is created, but isn't possible to reference the resource. deprecate?
    #produces("notify { [{nested => hash}]: }" => ["Notify[{nested => hash}]"]) #it is created, but isn't possible to reference the resource. deprecate?
    #produces("$x = [{nested => hash}] notify { $x: }" => ["Notify[{nested => hash}]"]) #it is created, but isn't possible to reference the resource. deprecate?

    fails(
      "notify { /regexp/: }" => /Syntax error/,
      "$x = /regexp/ notify { $x: }" => /Syntax error/,

      "notify { [/regexp/]: }" => /Syntax error/,
      "$x = [/regexp/] notify { $x: }" => /Syntax error/,

      "notify { default: }" => /Syntax error/,
      "$x = default notify { $x: }" => /Syntax error/,

      "notify { [default]: }" => /Syntax error/,
      "$x = [default] notify { $x: }" => /Syntax error/)
  end
end
