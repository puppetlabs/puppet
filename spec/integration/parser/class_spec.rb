require 'spec_helper'
require 'puppet_spec/language'

describe "Class expressions" do
  extend PuppetSpec::Language

  produces(
    "class hi { }"                                       => '!defined(Class[hi])',

    "class hi { } include hi"                            => 'defined(Class[hi])',
    "include(hi) class hi { }"                           => 'defined(Class[hi])',

    "class hi { } class { hi: }"                         => 'defined(Class[hi])',
    "class { hi: } class hi { }"                         => 'defined(Class[hi])',

    "class bye { } class hi inherits bye { } include hi" => 'defined(Class[hi]) and defined(Class[bye])')

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
