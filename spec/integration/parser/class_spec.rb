require 'spec_helper'
require 'puppet_spec/language'

describe "Class expressions" do
  extend PuppetSpec::Language

  before :each do
    Puppet[:parser] = 'future'
  end

  produces(
    "class hi { }"                                       => [],

    "class hi { } include hi"                            => ['Class[Hi]'],
    "include(hi) class hi { }"                           => ['Class[Hi]'],

    "class hi { } class { hi: }"                         => ['Class[Hi]'],
    "class { hi: } class hi { }"                         => ['Class[Hi]'],

    "class bye { } class hi inherits bye { } include hi" => ['Class[Hi]', 'Class[Bye]'])

  produces(<<-EXAMPLE => ['Notify[foo]', 'Notify[bar]'])
    class bar { notify { 'bar': } }
    class foo::bar { notify { 'foo::bar': } }
    class foo inherits bar { notify { 'foo': } }

    include foo
  EXAMPLE

  produces(<<-EXAMPLE => ['Notify[foo]', 'Notify[bar]'])
    class bar { notify { 'bar': } }
    class foo::bar { notify { 'foo::bar': } }
    class foo inherits ::bar { notify { 'foo': } }

    include foo
  EXAMPLE
end
