# A brief introduction to testing in Puppet

Puppet relies heavily on automated testing to ensure that Puppet behaves as
expected and that new features don't interfere with existing behavior. There are
three primary sets of tests that Puppet uses: _unit tests_, _integration tests_,
and _acceptance tests_.

- - -

Unit tests are used to test the individual components of Puppet to ensure that
they function as expected in isolation. Unit tests are designed to hide the
actual system implementations and provide canned information so that only the
intended behavior is tested, rather than the targeted code and everything else
connected to it. Unit tests should never affect the state of the system that's
running the test.

- - -

Integration tests serve to test different units of code together to ensure that
they interact correctly. While individual methods might perform correctly, when
used with the rest of the system they might fail, so integration tests are a
higher level version of unit tests that serve to check the behavior of
individual subsystems.

All of the unit and integration tests for Puppet are kept in the spec/ directory.

- - -

Acceptance tests are used to test high level behaviors of Puppet that deal with
a number of concerns and aren't easily tested with normal unit tests. Acceptance
tests function by changing system state and checking the system after
the fact to make sure that the intended behavior occurred. Because of this
acceptance tests can be destructive, so the systems being tested should be
throwaway systems.

All of the acceptance tests for Puppet are kept in the acceptance/tests/
directory. Running the acceptance tests is much more involved than running the
spec tests. Information about how to run them can be found in the [acceptance
testing documentation](acceptance_tests.md)

## Testing dependency version requirements

Puppet is only compatible with certain versions of RSpec and Mocha. If you are
not using Bundler to install the required test libraries you must ensure that
you are using the right library versions. Using unsupported versions of Mocha
and RSpec will probably display many spurious failures. The supported versions
of RSpec and Mocha can be found in the project Gemfile.

## Puppet Continuous integration

  * Travis-ci (spec tests only): https://travis-ci.org/puppetlabs/puppet/
  * Jenkins (spec and acceptance tests): https://jenkins.puppetlabs.com/view/Puppet%20FOSS/

## RSpec

Puppet uses RSpec to perform unit and integration tests. RSpec handles a number
of concerns to make testing easier:

  * Executing examples and ensuring the actual behavior matches the expected behavior (examples)
  * Grouping tests (describe and contexts)
  * Setting up test environments and cleaning up afterwards (before and after blocks)
  * Isolating tests (mocks and stubs)

#### Examples and expectations

At the most basic level, RSpec provides a framework for executing tests (which
are called examples) and ensuring that the actual behavior matches the expected
behavior (which are done with expectations)

```ruby
# This is an example; it sets the test name and defines the test to run
specify "one equals one" do
  # add an expectation that left and right arguments are equal
  expect(1).to eq(1)
end

# Examples can be declared with either 'it' or 'specify'
it "one doesn't equal two" do
  expect(1).to_not eq(2)
end
```

Good examples generally do as little setup as possible and only test one or two
things; it makes tests easier to understand and easier to debug.

More complete documentation on expectations is available at https://www.relishapp.com/rspec/rspec-expectations/docs

Note Puppet supports the [RSpec 3](http://rspec.info/blog/2013/07/the-plan-for-rspec-3/)
API, so please do not use RSpec 2 "should" syntax like `1.should == 1`.

### Example groups

Example groups are fairly self explanatory; they group similar examples into a
set.

```ruby
describe "the number one" do

  it "is larger than zero" do
    expect(1).to be > 0
  end

  it "is an odd number" do
    expect(1).to be_odd # calls 1.odd?
  end

  it "is not nil" do
    expect(1).to be
  end
end
```

Example groups have a number of uses that we'll get into later, but one of the
simplest demonstrations of what they do is how they help to format
documentation:

```
rspec ex.rb --format documentation

the number one
  is larger than zero
  is an odd number
  is not nil

Finished in 0.00516 seconds
3 examples, 0 failures
```

### Setting up and tearing down tests

Examples may require some setup before they can run, and might need to clean up
afterwards. `before` and `after` blocks can be used before this, and can be
used inside of example groups to limit how many examples they affect.

```ruby

describe "something that could warn" do
  before :each do
    # Disable warnings for this test
    $VERBOSE = nil
  end

  after :each do
    # Enable warnings afterwards
    $VERBOSE = true
  end

  it "doesn't generate a warning" do
    MY_CONSTANT = 1
    # reassigning a constant normally prints out 'warning: already initialized constant FOO'
    MY_CONSTANT = 2
  end
end
```

### Setting up helper data

Some examples may require setting up data before hand and making it available to
tests. RSpec provides helper methods with the `let` method call that can be used
inside of tests.

```ruby
describe "a helper object" do
  # This creates an array with three elements that we can retrieve in tests. A
  # new copy will be made for each test.
  let(:my_helper) do
    ['foo', 'bar', 'baz']
  end

  it "is an array" do
    expect(my_helper).to be_a_kind_of Array
  end

  it "has three elements" do
    expect(my_helper.size).to eq(3)
  end
end
```

Like `before` blocks, helper objects like this are used to avoid doing a lot of
setup in individual examples and share setup between similar tests.

### Isolating tests with stubs

RSpec allows you to provide fake data during testing to make sure that
individual tests are only running the code being tested. You can stub out entire
objects, or just stub out individual methods on an object. When a method is
stubbed the method itself will never be called.

While RSpec comes with its own stubbing framework, Puppet uses the Mocha
framework.

A brief usage guide for Mocha is available at http://gofreerange.com/mocha/docs/#Usage,
and an overview of Mocha expectations is available at http://gofreerange.com/mocha/docs/Mocha/Expectation.html

```ruby
describe "stubbing a method on an object" do
  let(:my_helper) do
    ['foo', 'bar', 'baz']
  end

  it 'has three items before being stubbed' do
    expect(my_helper.size).to eq(3)
  end

  describe 'when stubbing the size' do
    before :each do
      my_helper.stubs(:size).returns 10
    end

    it 'has the stubbed value for size' do
      expect(my_helper.size).to eq(10)
    end
  end
end
```

Entire objects can be stubbed as well.

```ruby
describe "stubbing an object" do
  let(:my_helper) do
    stub(:not_an_array, :size => 10)
  end

  it 'has the stubbed size'
    expect(my_helper.size).to eq(10)
  end
end
```

### Adding expectations with mocks

It's possible to combine the concepts of stubbing and expectations so that a
method has to be called for the test to pass (like an expectation), and can
return a fixed value (like a stub).

```ruby
describe "mocking a method on an object" do
  let(:my_helper) do
    ['foo', 'bar', 'baz']
  end

  describe "when mocking the size" do
    before :each do
      my_helper.expects(:size).returns 10
    end

    it "adds an expectation that a method was called" do
      my_helper.size
    end
  end
end
```

Like stubs, entire objects can be mocked.

```ruby
describe "mocking an object" do
  let(:my_helper) do
    mock(:not_an_array)
  end

  before :each do
    not_an_array.expects(:size).returns 10
  end

  it "adds an expectation that the method was called" do
    not_an_array.size
  end
end
```
### Writing tests without side effects

When properly written each test should be able to run in isolation, and tests
should be able to be run in any order. This makes tests more reliable and allows
a single test to be run if only that test is failing, instead of running all
17000+ tests each time something is changed. However, there are a number of ways
that can make tests fail when run in isolation or out of order.

#### Narrowing down a spec test with side effects

If you do have a test that passes in isolation but fails when run as part of
a full spec run, you can often narrow down the culprit by a two-step process.
First, run:

```
bundle exec rake ci:spec
```

which should generate a spec_order.txt file.

Second, run:

```
util/binary_search_specs.rb <full path to failing spec>
```

And it will (usually) tell you the test that makes the failing spec fail.

The 'usually' caveat is because there can be spec failures that require
specific ordering between > 2 spec files, and this tool only handles the
case for 2 spec files. The > 2 case is rare and if you suspect you're in
that boat, there isn't an established best practice, other than to ask
for help on IRC or the mailing list.

#### Using instance variables

Puppet has a number of older tests that use `before` blocks and instance
variables to set up fixture data, instead of `let` blocks. These can retain
state between tests, which can lead to test failures when tests are run out of
order.

```ruby
# test.rb
RSpec.configure do |c|
  c.mock_framework = :mocha
end

describe "fixture data" do
  describe "using instance variables" do

    # BAD
    before :all do
      # This fixture will be created only once and will retain the `foo` stub
      # between tests.
      @fixture = stub 'test data'
    end

    it "can be stubbed" do
      @fixture.stubs(:foo).returns :bar
      expect(@fixture.foo).to eq(:bar)
    end

    it "does not keep state between tests" do
      # The foo stub was added in the previous test and shouldn't be present
      # in this test.
      expect { @fixture.foo }.to raise_error
    end
  end

  describe "using `let` blocks" do

    # GOOD
    # This will be recreated between tests so that state isn't retained.
    let(:fixture) { stub 'test data' }

    it "can be stubbed" do
      fixture.stubs(:foo).returns :bar
      expect(fixture.foo).to eq(:bar)
    end

    it "does not keep state between tests" do
      # since let blocks are regenerated between tests, the foo stub added in
      # the previous test will not be present here.
      expect { fixture.foo }.to raise_error
    end
  end
end
```

```
bundle exec rspec test.rb -fd

fixture data
  using instance variables
    can be stubbed
    should not keep state between tests (FAILED - 1)
  using `let` blocks
    can be stubbed
    should not keep state between tests

Failures:

  1) fixture data using instance variables should not keep state between tests
     Failure/Error: expect { @fixture.foo }.to raise_error
       expected Exception but nothing was raised
     # ./test.rb:17:in `block (3 levels) in <top (required)>'

Finished in 0.00248 seconds
4 examples, 1 failure

Failed examples:

rspec ./test.rb:16 # fixture data using instance variables should not keep state between tests
```

### RSpec references

  * RSpec core docs: https://www.relishapp.com/rspec/rspec-core/docs
  * RSpec guidelines with Ruby: http://betterspecs.org/

