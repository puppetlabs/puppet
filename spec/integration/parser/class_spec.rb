require 'spec_helper'
require 'puppet_spec/language'

describe "Class expressions" do
  extend PuppetSpec::Language

  produces(
    "class hi { }"                                       => '!defined(Class[Hi])',

    "class hi { } include hi"                            => 'defined(Class[Hi])',
    "include(hi) class hi { }"                           => 'defined(Class[Hi])',

    "class hi { } class { hi: }"                         => 'defined(Class[Hi])',
    "class { hi: } class hi { }"                         => 'defined(Class[Hi])',

    "class bye { } class hi inherits bye { } include hi" => 'defined(Class[Hi]) and defined(Class[Bye])')

  produces(<<-EXAMPLE => 'defined(Notify[foo]) and defined(Notify[bar]) and !defined(Notify[foo::bar])')
    class bar { notify { 'bar': } }
    class foo::bar { notify { 'foo::bar': } }
    class foo inherits bar { notify { 'foo': } }

    include foo
  EXAMPLE

  produces(<<-EXAMPLE => 'defined(Notify[foo]) and defined(Notify[bar]) and !defined(Notify[foo::bar])')
    class bar { notify { 'bar': } }
    class foo::bar { notify { 'foo::bar': } }
    class foo inherits ::bar { notify { 'foo': } }

    include foo
  EXAMPLE
end
