# ptomulik-vash

[![Build Status](https://travis-ci.org/ptomulik/puppet-vash.png?branch=master)](https://travis-ci.org/ptomulik/puppet-vash)
[![Coverage Status](https://coveralls.io/repos/ptomulik/puppet-vash/badge.png)](https://coveralls.io/r/ptomulik/puppet-vash)
[![Code Climate](https://codeclimate.com/github/ptomulik/puppet-vash.png)](https://codeclimate.com/github/ptomulik/puppet-vash)

#### Table of Contents

1. [Overview](#overview)
2. [Module Description](#module-description)
3. [Beginning with vash](#beginning-with-vash)
4. [Usage](#usage)
5. [Reference](#reference)
6. [Testing](#testing)
7. [Limitations](#limitations)
8. [Development](#development)

## Overview

*Vash* (a validating hash) provides mixins to create
[Hash](http://www.ruby-doc.org/core/Hash.html)-like classes with simple
validation and munging of input data.

# Module Description

Vash provides mixins that add [Hash](http://www.ruby-doc.org/core/Hash.html)
interface to receiving classes. The mixins allow you to enable simple data
validation and munging, such that you may define restrictions on keys, values
and pairs entering your hash and coalesce them at input.

## Beginning with vash

There are two ways to add *Vash* functionality to your class. The first one is
to use `Vash::Contained` mixin, as follows

```ruby
require 'puppet/util/vash/contained'
class MyVash
  include Puppet::Util::Vash::Contained
end
```

The second pattern is to use `Vash::Inherited`

```ruby
require 'puppet/util/vash/inherited'
class MyVash < Hash
  include Puppet::Util::Vash::Inherited
end
```

With the first pattern, hash data is kept in an instance variable named
`@vash_underlying_hash` and may be internally accessed via
`vash_underlying_hash` private method.

With second pattern the superclass of `MyVash` must provide `Hash` interface
(read - it should be a subclass of standard
[Hash](http://www.ruby-doc.org/core/Hash.html)).

Once you have included `Vash::Contained` or `Vash::Inherited` module to your
class, you may use it as ordinary Hash:

```ruby
vash = MyVash[ [[:a,:A],[:b,:B]] ]
vash[:c] = :C
# .. and so on
```

The default rules for validation and munging are "allow anything" and "do not
modify", so `MyVash` behaves exactly same way `Hash` does. Simple validation
may be added by defining `vash_valid_key?`, `vash_valid_value?` and
`vash_valid_pair?` methods (note, all methods that are specific to Vash, have
`vash_` prefix):

```ruby
require 'puppet/util/vash/contained'
class MyVash
  include Puppet::Util::Vash::Contained
  # accept only integers as keys
  def vash_valid_key?(key)
    true if Integer(key) rescue false
  end
end
```

```ruby
vash = MyVash[1,2]
# => {1=>2}
vash[2] = 3
# => 3
vash
# => {1=>2, 2=>3}
vash['a'] = 1
# InvalidKeyError: invalid key "a"
```

Restrictions may further be defined for values and pairs. The following
subsections shall give more detailed explanations.

## Usage

Custom Hash with validation and munging (call it "custom Vash") may be created
by including `Puppet::Util::Vash::Contained` or
`Puppet::Util::Vash::Inherited` module to your class and then
overwriting some of its methods. It's also good to prepare some specs/tests for
your customized class (see [Testing](#testing)). 

We'll start with simple customized Vash in 
[Example 3.1](#example-31-defining-restrictions-for-keys-and-values)
and will continue extending it in subsequent examples.

#### Example 3.1: Defining restrictions for keys and values

Let's prepare simple container for integer variables:

```ruby
require 'puppet/util/vash/contained'
class Variables
  include Puppet::Util::Vash::Contained
  # accept only valid identifiers as keys
  def vash_valid_key?(key)
    key.is_a?(String) and (key=~/^[a-zA-Z]\w*$/)
  end
  # accept only what is convertible to integer
  def vash_valid_value?(val)
    true if Integer(val) rescue false
  end
end
```

When you perform simple experiments, you shall see:

```ruby
vars = Variables['ten', 10, 'nine', 9]
# => {"nine"=>9,"ten"=>10}
vars[2] = 20
# InvalidKeyError: invalid key 2
vars['eight'] = 'e'
# InvalidValueError: invalid value "e" at key "eight"
vars['seven'] = '7'
# => "7"
vars
# => {"nine"=>9, "ten"=>10, "seven"=>"7"}
```

#### Example 3.2: Munging keys and values

The class from [Example 3.1](#example-31-defining-restrictions-for-keys-and-values)
has one drawback - it doesn't convert values to integers. For example
`vars['seven']` is `"7"` (a string). Value munging may be added to `Variables`
in order to convert data provided by user.

```ruby
class Variables
  def vash_munge_value(val)
    Integer(val)
  end
end
```

Now we have

```ruby
vars = Variables['seven','7']
# => {"seven"=>7}
```

We may also munge keys, for example convert `camelCase` to `under\_score`:

```ruby
class Variables
  def vash_munge_key(key)
    key.gsub(/([a-z])([A-Z])/,'\1_\2').downcase
  end
end
```

```ruby
vars = Variables['TwentyFive','25']
# => {"twenty_five"=>25}
```

#### Example 3.3: Defining restrictions for pairs

Some variables may not accept certain values. To prevent Vash from accepting
such pairs, a pair validation may be used. In this example we prevent variables
ending with `_price` from accepting negative values:

```ruby
class Variables
  # for keys ending with _price we accept only non-negative values
  def vash_valid_pair?(pair)
    (pair[0]=~/price$/) ? (pair[1]>=0) : true
  end
end
```

```ruby
vars = Variables['lemonPrice', '-4']
# InvalidPairError: invalid (key,value) combination ("lemon_price",-4) at index 0
```

#### Example 3.4: Munging pairs

We may also munge pairs entering our `Variables` container. In this example
we'll append variable value to its name, such that `vars['my_var'] = 1` will 
result with variable `my_var1=1` being added to `Variables`:

```ruby
class Variables
  def vash_munge_pair(pair)
    [pair[0] + pair[1].to_s, pair[1]]
  end
end
```

```ruby
vars = Variables['myVar', 1]
# => {"my_var1"=>1}
vars['my_var'] = 2
# => 2
vars
# => {"my_var2"=>2, "my_var1"=>1}
```

#### Example 3.5: Customizing error messages

Default error messages may be misleading in certain applications. To circumvent
this, we may override `vash_key_name`, `vash_value_name` and `vash_pair_name`,
for example:

```ruby
class Variables
  def vash_key_name(*args); 'variable name'; end
  def vash_value_name(*args); 'variable value'; end
  def vash_pair_name(*args); 'value for variable'; end
end
```

```ruby
vars = Variables[:xxx, 1]
# InvalidKeyError: invalid variable name :xxx at index 0
vars = Variables['var', 'xxx']
# InvalidValueError: invalid variable value "xxx" at index 1
vars = Variables['lemonPrice', '-4']
# InvalidPairError: invalid value for variable ("lemon_price",-4) at index 0
```

The last message is still not well-formed. We may overwrite default
`#vash_pair_exception` to have better effect:

```ruby
class Variables
  # note: args[0] optionally contains index of a failing pair
  def vash_pair_exception(pair, *args)
    msg  = "invalid value #{pair[1].inspect} for variable #{pair[0].inspect}"
    msg += " at index #{args[0]}" unless args[0].nil?
    [Puppet::Util::Vash::InvalidPairError, msg]
  end
end
```

```ruby
vars = Variables['lemonPrice', -1]
# InvalidPairError: invalid value -1 for variable lemon_price at index 0
```

## Reference

The detailed method documentation may be generated with *yardoc*. Here, we only
present briefly how *Vash* works.

When new data enters `Vash` (via `#[]=`, `#store` or any other method that
modifies content of the underlying hash), the workflow is following:

1. Input items are passed to `#vash_validate_item` (the term *item* is used
   for original `[key,value]` pair as entered by user).
2. The key and value are validated separately by `#vash_validate_key` and
   `#vash_validate_value`. These methods call `#vash_valid_key?` and
   `#vash_valid_value?` to ask, if the key and value may be further
   processed.
3. If key and value are acceptable, the `#vash_munge_key` and
   `#vash_munge_value` are called to perform optional data munging.
   The `#vash_validate_key` and `#vash_validate_value` return munged key and
   value.
4. The munged `[key,value]` pair is referred to as *pair*. It is passed to
   `#vash_validate_pair` in order to ensure, that it satisfies pair
   restrictions. The `#vash_validate_pair` asks `#vash_valid_pair?` whether the
   given pair may be accepted or not (note: both methods operate on already
   munged keys and values).
5. If verification succeeds, the pair is passed to `#vash_munge_pair` and
   added to Vash container.

In any of these points, if the validation fails, an exception is raised. The
`Vash` by default raises following exceptions:

* `Puppet::Util::Vash::InvalidKeyError` (key validation failed),
* `Puppet::Util::Vash::InvalidValueError` (value validation failed),
* `Puppet::Util::Vash::InvalidPairError` (pair validation failed).

All the above exceptions are subclasses of 

* `Puppet::Util::Vash::VashArgumentError`.

which is a subclass of `::ArumentError`.

## Testing

To run existing unit tests simply type

```bash
bundle exec rake spec
```

Note, that you may need to install necessary gems to run tests:

```bash
bundle install --path vendor/bundle
```

### Shared examples overview

The module provides quite extensive set of rspec shared examples for
developers. The tests are designed such that they compare behaviour of a
subject class with an already-tested (model) class (such as standard `Hash`).
Reusable *shared\_examples* are provided for developers who want to implement
custom *Vashes*. If you're starting your new *Vash* class, it's recommended to
prepare simple test that includes *Vash::Inherited* or *Vash::Contained* shared
examples and run test each time you overwrite some of
`Vash::Contained`, `Vash::Inherited` or `Vash::Validator` methods. This shall
quickly reveal any (unintended) changes introduced to your *Vash* behaviour.

The shared examples may be found in following files:

* *spec/shared_behaviours/vash/hash.rb*
* *spec/shared_behaviours/vash/validator.rb*
* *spec/shared_behaviours/vash/contained.rb*
* *spec/shared_behaviours/vash/inherited.rb*

#### Example 6.1

Say, we want to ensure, that our new class:

```ruby
class MyHash < Hash; end
```

has all the functionality of standard `Hash`. We may use `Vash::Hash` 
*shared\_examples* to verify, that our class has the expected behaviour:

```ruby
# spec/unit/my_hash_spec.rb
require 'spec_helper'
require 'shared_behaviours/vash/hash'

class MyHash < Hash; end

describe MyHash do
  it_behaves_like 'Vash::Hash', {
    :sample_items   => [ [:a,:A,], ['b','B'] ],
    :hash_arguments => [ { :a=>:X, :d=>:D } ],
    :missing_key    => :c,
    :missing_value  => :C
  }
end

```

The above snippet shall generate about 700 test cases. Because `MyHash` has all
the functionality of `Hash`, we expect all tests to pass. 

The `:sample_items` array is used to initialize hash during the tests and also
to generate input arguments to some hash functions (keys/values from
`sample_items` may be used as `existing_key` and `existing_value`). The
`:hash_arguments` is an array of hashes used to test methods accepting hash as
an argument (e.g. `merge!`). The `:missing_key` and `:missing_value` are sample
key and value that are correct (should pass key/value and pair validation) but
is not present in `:sample_items`.

#### Example 6.2

Now suppose, you want to add input validation to *MyHash* and then test its
behaviour. For that, we include `Puppet::Util::Vash::Inherited`
module, and use *Vash::Inherited* shared examples.

```ruby
# spec/unit/my_vash_spec.rb
require 'spec_helper'
require 'shared_behaviours/vash/inherited'
require 'puppet/util/vash/inherited'

class MyHash < Hash
  include Puppet::Util::Vash::Inherited 
  # accept only valid identifiers as keys
  def vash_valid_key?(key)
    key.is_a?(String) and (key=~/^[a-zA-Z]\w*$/)
  end
end

describe MyHash do
  it_behaves_like 'Vash::Inherited', {
    :valid_keys        => ['iden_tifier', 'IdenTifier'],
    :invalid_keys      => ['', '$#', :a, {}, [], nil],
    :valid_items       => [ ['x', 1] ],
    :invalid_items     => [ [[:x, 'a'], :key] ],
    :hash_arguments    => [ { 'a'=>:A, 'b'=>'B' } ],
    :missing_key       => 'c',
    :missing_value     => :C,
    :methods           => {
      :vash_valid_key? => lambda{|key| key.is_a?(String) and (key=~/^[a-zA-Z]\w*$/)}
    }
  }
end
```

In the above snippet, we've indicated that *MyHash* has the behaviour of
*Vash::Inherited*, but the `vash_valid_key?` method was overridden. We indicate
this by setting *:vash_valid_key?* parameter in *:methods*.

### Shared examples reference

#### *Vash::Hash* shared examples

Ensures that a class behaves like standard `Hash`.

*Synopsis*:

```ruby
it_behaves_like 'Vash::Hash', params
```

The `params` is a Hash with parameters used by test driver.

*Example usage*:

```ruby
require 'shared_behaviours/vash/hash'
# ...
# MyHash is the class under test
describe MyHash do
  it_behaves_like 'Vash::Hash', {
    :sample_items   => [ [:a,:A,], ['b','B'] ],
    :hash_arguments => [ { :a=>:X, :d=>:D } ],
    :missing_key    => :c,
    :missing_value  => :C
  }
end
```

*Parameters*:

* *sample_items* (required) - used to determine key/value arguments to tested
  methods and *existing_key*/ *existing_value* (if not present in params); also
  used to initialize instances of described class before they get tested
  (unless *hash_initializers* parameter is provided); the *sample_items*
  parameter may be a Hash or an array of items (array of 2-element arrays),
* *missing_key* (required) - an example key that is not in *sample_items*,
* *missing_value* (required) - an example value that is not in *sample_items*,
* *hash_arguments* (required) - an array of hashes used as arguments to some
  tested methods (those, that accept hash as argument, for example `merge!`),
* *model_class* (optional) - a class which models expected Hash behaviour,
   by default `Puppet::SharedBehaviours::Vash::Hash` is used,
   which is direct subclass of standard `Hash`,
* *methods* (optional) - a hash of procs/lambdas used to override methods in
  the model class. This may be used to slightly modify model behaviour used
  by shared examples, for example:

  ```ruby
  # slightly modified hash ...
  class MyHash < Hash
    def default; nil; end
    def default=(v); raise RuntimeError, "can't change default value"; end
  end
  describe MyHash do
    it_behaves_like 'Vash::Hash', {
      # ... other params ...
      :methods => {
        :default  => lambda { nil } # our #default method always returns nil
        :default= => lambda { |v| raise RuntimeError, "can't change default value" }
      }
    }
  end
  ```
* *hash_initializers* (optional) - an Array of hashes, used to initialize
  instances of the tested class and generate tests with such an initialized
  instances; if not provided, *sample_items* parameter is used to initialize
  one instance per method.

* *disable_exception_matching* (optional) - if set to *true*, do not specify,
  that subject's methods behave exactly as model's method with respect to the
  raised exceptions,
* *disable_value_matching* (optional) - if set to *true*, do not verify whether
  the values returned by the subject's methods are same as values returned by
  model's methods,
* *disable_class_check* (optional) - if set to *true*, do not check whether the
  classes of values returned by subject's methods are correct,
* *disable_value_is_self_check* (optional) - some Hash methods are supposed to
  return *self* object, (for example `merge!`); if this flag is set to *true*,
  do not check whether these methods return *self* object properly,
* *match_attributes* (optional) - an array of subject's attributes to match
  against appropriate attributes; the attributes are not part of hash content;
  an example attribute is *default* value.
* *match_attributes_at_end* (optional) - an array of attributes to match
  against model after the operation under test (e.g. `:match_attributes =>
  :default` causes that *default* values of subject and model hashes are
  compared after the tested method is invoked),
* *disable_content_matching* - do not test whether the content of subject and
  model hash is same after the operation under test,
* *raises* - an array of exception classes that may be raised by function as a
  part of its normal behaviour (for example as a result of argument validation)
  

Most of these parameters might be overwritten on per-method basis, for example:

```ruby
it_behaves_like 'Hash::Vash', {
  # ...
  :fetch => { :disable_value_matching => true },
}
```

#### *Vash::Validator* shared examples

Ensure that a class provides all functionalities of
`Puppet::Util::Vash::Validator`.

*Synopsis*
```ruby
it_behaves_like 'Vash::Validator', params
```

*Example:*:

```ruby
require 'puppet/util/vash/validator'
require 'shared_behaviours/vash/validator'
class MyValidator
  include Puppet::Util::Vash::Validator
  # accept only valid identifiers as keys
  def vash_valid_key?(key)
    key.is_a?(String) and (key=~/^[a-zA-Z]\w*$/)
  end
  # accept only what is convertible to integer
  def vash_valid_value?(val)
    true if Integer(val) rescue false
  end
end

describe MyValidator do
  it_behaves_like 'Vash::Validator', {
    :valid_keys     => ['one', 'two'],
    :invalid_keys   => ["7'th",''],
    :valid_values   => [1,-1,'0'],
    :invalid_values => [{},'x'],
  }
end
```

*Parameters*:

See comments in source code: *spec/shared_behaviours/vash/validator.rb*.

#### *Vash::Contained* and *Vash::Inherited* shared examples

The *Vash::Contained* (or *Vash::Inherited*) combines *Vash:Hash* and
*Vash::Validator* shared examples into single set of shared examples.

*Synopsis*

```ruby
it_behaves_like 'Vash::Contained', params
```

or

```ruby
it_behaves_like 'Vash::Inherited', params
```

where `params` is a Hash of mixed parameters to `Vash::Hash` and
`Vash::Validator` behaviours. Note, that you don't have to define
*sample_items*, because they are internally generated from *valid_items* and
*invalid_items*. The *hash_initializers*, if provided, must consists only of
valid items or your tests will fail.

## Development

The project is held at github:

* [https://github.com/ptomulik/puppet-vash](https://github.com/ptomulik/puppet-vash)

Issue reports, patches, pull requests are welcome!
