require 'spec_helper'
require 'puppet_spec/language'

describe "Puppet resource expressions" do
  extend PuppetSpec::Language

  produces(
  "$a = notify
       $b = example
       $c = { message => hello }
       @@Resource[$a] {
         $b:
           * => $c
       }
       realize(Resource[$a, $b])
       " => "Notify[example][message] == 'hello'")

  context "resource titles" do
    produces(
    "notify { thing: }"                     => "defined(Notify[thing])",
    "$x = thing notify { $x: }"             => "defined(Notify[thing])",

    "notify { [thing]: }"                   => "defined(Notify[thing])",
    "$x = [thing] notify { $x: }"           => "defined(Notify[thing])",

    "notify { [[nested, array]]: }"         => "defined(Notify[nested]) and defined(Notify[array])",
    "$x = [[nested, array]] notify { $x: }" => "defined(Notify[nested]) and defined(Notify[array])",

    "notify { []: }"                        => [], # this asserts nothing added
    "$x = [] notify { $x: }"                => [], # this asserts nothing added

    "notify { default: }"                   => "!defined(Notify['default'])", # nothing created because this is just a local default
    "$x = default notify { $x: }"           => "!defined(Notify['default'])")

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
    produces( "notify { testing: }"                            => "defined(Notify[testing])")
    produces( "$a = notify; Resource[$a] { testing: }"         => "defined(Notify[testing])")
    produces( "Resource['notify'] { testing: }"                => "defined(Notify[testing])")
    produces( "Resource[sprintf('%s', 'notify')] { testing: }" => "defined(Notify[testing])")
    produces( "$a = ify; Resource[\"not$a\"] { testing: }"     => "defined(Notify[testing])")

    produces( "Notify { testing: }"           => "defined(Notify[testing])")
    produces( "Resource[Notify] { testing: }" => "defined(Notify[testing])")
    produces( "Resource['Notify'] { testing: }"         => "defined(Notify[testing])")

    produces( "class a { notify { testing: } } class { a: }"   => "defined(Notify[testing])")
    produces( "class a { notify { testing: } } Class { a: }"   => "defined(Notify[testing])")
    produces( "class a { notify { testing: } } Resource['class'] { a: }" => "defined(Notify[testing])")

    produces( "define a::b { notify { testing: } } a::b { title: }" => "defined(Notify[testing])")
    produces( "define a::b { notify { testing: } } A::B { title: }" => "defined(Notify[testing])")
    produces( "define a::b { notify { testing: } } Resource['a::b'] { title: }" => "defined(Notify[testing])")

    fails( "'class' { a: }"              => /Illegal Resource Type expression.*got String/)
    fails( "'' { testing: }"             => /Illegal Resource Type expression.*got String/)
    fails( "1 { testing: }"              => /Illegal Resource Type expression.*got Integer/)
    fails( "3.0 { testing: }"            => /Illegal Resource Type expression.*got Float/)
    fails( "true { testing: }"           => /Illegal Resource Type expression.*got Boolean/)
    fails( "'not correct' { testing: }"  => /Illegal Resource Type expression.*got String/)

    fails( "Notify[hi] { testing: }"     => /Illegal Resource Type expression.*got Notify\['hi'\]/)
    fails( "[Notify, File] { testing: }" => /Illegal Resource Type expression.*got Array\[Type\[Resource\]\]/)

    fails( "define a::b { notify { testing: } } 'a::b' { title: }" => /Illegal Resource Type expression.*got String/)

    fails( "Does::Not::Exist { title: }" => /Resource type not found: Does::Not::Exist/)
  end

  context "local defaults" do
    produces(
    "notify { example:;                     default: message => defaulted }" => "Notify[example][message] == 'defaulted'",
    "notify { example: message => specific; default: message => defaulted }" => "Notify[example][message] == 'specific'",
    "notify { example: message => undef;    default: message => defaulted }" => "Notify[example][message] == undef",
    "notify { [example, other]: ;           default: message => defaulted }" => "Notify[example][message] == 'defaulted' and Notify[other][message] == 'defaulted'",
    "notify { [example, default]: message => set; other: }"                  => "Notify[example][message] == 'set' and Notify[other][message] == 'set'")
  end

  context "order of evaluation" do
    fails("notify { hi: message => value; bye: message => Notify[hi][message] }" => /Resource not found: Notify\['hi'\]/)

    produces("notify { hi: message => (notify { param: message => set }); bye: message => Notify[param][message] }" => "defined(Notify[hi]) and Notify[bye][message] == 'set'")
    fails("notify { bye: message => Notify[param][message]; hi: message => (notify { param: message => set }) }" => /Resource not found: Notify\['param'\]/)
  end

  context "parameters" do
    produces(
    "notify { title: message => set }"                   => "Notify[title][message] == 'set'",
    "$x = set notify { title: message => $x }"           => "Notify[title][message] == 'set'",

    "notify { title: *=> { message => set } }"           => "Notify[title][message] == 'set'",

    "$x = { message => set } notify { title: * => $x }"  => "Notify[title][message] == 'set'",

    # picks up defaults
    "$x = { owner => the_x }
         $y = { mode =>  '0666' }
         $t = '/tmp/x'
         file {
           default:
             * => $x;
           $t:
             path => '/somewhere',
             * => $y }"  => "File[$t][mode] == '0666' and File[$t][owner] == 'the_x' and File[$t][path] == '/somewhere'",

    # explicit wins over default - no error
    "$x = { owner => the_x, mode => '0777' }
         $y = { mode =>  '0666' }
         $t = '/tmp/x'
         file {
           default:
             * => $x;
           $t:
             path => '/somewhere',
             * => $y }"  => "File[$t][mode] == '0666' and File[$t][owner] == 'the_x' and File[$t][path] == '/somewhere'")

    produces("notify{title:}; Notify[title] { * => { message => set}}"  => "Notify[title][message] == 'set'")
    produces("Notify { * => { message => set}}; notify{title:}"         => "Notify[title][message] == 'set'")
    produces('define foo($x) { notify { "title": message =>"aaa${x}bbb"} } foo{ test: x => undef }' => "Notify[title][message] == 'aaabbb'")
    produces('define foo($x="xx") { notify { "title": message =>"aaa${x}bbb"} } foo{ test: x => undef }' => "Notify[title][message] == 'aaaxxbbb'")

    fails("notify { title: unknown => value }" => /no parameter named 'unknown'/)

    # this really needs to be a better error message.
    fails("notify { title: * => { hash => value }, message => oops }" => /no parameter named 'hash'/)

    # should this be a better error message?
    fails("notify { title: message => oops, * => { hash => value } }" => /no parameter named 'hash'/)

    fails("notify { title: * => { unknown => value } }" => /no parameter named 'unknown'/)
    fails("
         $x = { mode => '0666' }
         $y = { owner => the_y }
         $t = '/tmp/x'
         file { $t:
           * => $x,
           * => $y }"  => /Unfolding of attributes from Hash can only be used once per resource body/)
  end

  context "virtual" do
    produces(
    "@notify { example: }"                     => "!defined(Notify[example])",

    "@notify { example: }
         realize(Notify[example])"                 => "defined(Notify[example])",

    "@notify { virtual: message => set }
         notify { real:
           message => Notify[virtual][message] }"  => "Notify[real][message] == 'set'")
  end

  context "exported" do
    produces(
    "@@notify { example: }" => "!defined(Notify[example])",
    "@@notify { example: } realize(Notify[example])" => "defined(Notify[example])",
    "@@notify { exported: message => set } notify { real: message => Notify[exported][message] }" => "Notify[real][message] == 'set'")
  end

  context "explicit undefs" do
    # PUP-3505
    produces("
        $x = 10
        define foo($x = undef) {
          notify { example:
            message => \"'$x'\"
          }
        }
        foo {'blah': x => undef }
      " => "Notify[example][message] == \"''\"")
  end
end

