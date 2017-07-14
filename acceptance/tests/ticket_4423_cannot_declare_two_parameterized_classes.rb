# Jeff McCune <jeff@puppetlabs.com>
# 2010-07-31
#
# AffectedVersion: 2.6.0, 2.6.1rc1
# FixedVersion:
#
# Make sure two parameterized classes are able to be declared.

test_name "#4423: cannot declare two parameterized classes"

tag 'audit:high', # basic language functionality
    'audit:unit',
    'audit:refactor', # Use block style `test_name`
    'audit:delete'

class1 = %q{
    class rainbow($color) {
      notify { "color": message => "Color is [${color}]" }
    }
    class { "rainbow": color => "green" }
}

class2 = %q{
    class planet($moons) {
      notify { "planet": message => "Moons are [${moons}]" }
    }
    class { "planet": moons => "1" }
}

step "Declaring one parameterized class works just fine"
apply_manifest_on(agents, class1)

step "Make sure we try both classes stand-alone"
apply_manifest_on(agents, class2)

step "Putting both classes in the same manifest should work."
apply_manifest_on agents, class1 + class2

step "Putting both classes in the same manifest should work."
apply_manifest_on agents, class1+class2+%q{

    class rainbow::location($prism=false, $water=true) {
      notify { "${name}":
        message => "prism:[${prism}] water:[${water}]";
      }
    }
    class { "rainbow::location": prism => true, water => false; }

    class rainbow::type($pretty=true, $ugly=false) {
      notify { "${name}":
        message => "pretty:[${pretty}] ugly:[${ugly}]";
      }
    }
    class { "rainbow::type": pretty => false, ugly => true; }
}
