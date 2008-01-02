# Examples with no descriptions
# * should equal 5
# * should be < 5
# * should include "a"
# * should respond to #size
# State created in before(:all)
# * should be accessible from example
# * should not have sideffects
# BehaveAsExample::BluesGuitarist
# * should behave as guitarist
# BehaveAsExample::RockGuitarist
# * should behave as guitarist
# BehaveAsExample::ClassicGuitarist
# * should not behave as guitarist
# Animals::Mouse
# * should eat cheese
# * should not eat cat
# Some integers
# * The root of 1 square should be 1
# * The root of 2 square should be 2
# * The root of 3 square should be 3
# * The root of 4 square should be 4
# * The root of 5 square should be 5
# * The root of 6 square should be 6
# * The root of 7 square should be 7
# * The root of 8 square should be 8
# * The root of 9 square should be 9
# * The root of 10 square should be 10
# A FileAccessor
# * should open a file and pass it to the processor's process method
# Greeter
# * should say Hi to person
# * should say Hi to nobody
# a context with helper a method
# * should make that method available to specs
# An IoProcessor
# * should raise nothing when the file is exactly 32 bytes
# * should raise an exception when the file length is less than 32 bytes
# A legacy spec
# * should work fine
# A consumer of a mock
# * should be able to send messages to the mock
# a mock
# * should be able to mock the same message twice w/ different args
# * should be able to mock the same message twice w/ different args in reverse order
# A partial mock
# * should work at the class level
# * should revert to the original after each spec
# * can be mocked w/ ordering
# pending example (using pending method)
# * pending example (using pending method) should be reported as "PENDING: for some reason" [PENDING: for some reason]
# pending example (with no block)
# * pending example (with no block) should be reported as "PENDING: Not Yet Implemented" [PENDING: Not Yet Implemented]
# pending example (with block for pending)
# * pending example (with block for pending) should have a failing block, passed to pending, reported as "PENDING: for some reason" [PENDING: for some reason]
# BDD framework
# * should be adopted quickly
# * should be intuitive
# SharedBehaviourExample::OneThing
# * should do what things do
# * should have access to helper methods defined in the shared behaviour
# SharedBehaviourExample::AnotherThing
# * should do what things do
# Stack (empty)
# * should be empty
# * should not be full
# * should add to the top when sent #push
# * should complain when sent #peek
# * should complain when sent #pop
# Stack (with one item)
# * should not be empty
# * should return the top item when sent #peek
# * should NOT remove the top item when sent #peek
# * should return the top item when sent #pop
# * should remove the top item when sent #pop
# * should not be full
# * should add to the top when sent #push
# Stack (with one item less than capacity)
# * should not be empty
# * should return the top item when sent #peek
# * should NOT remove the top item when sent #peek
# * should return the top item when sent #pop
# * should remove the top item when sent #pop
# * should not be full
# * should add to the top when sent #push
# Stack (full)
# * should be full
# * should not be empty
# * should return the top item when sent #peek
# * should NOT remove the top item when sent #peek
# * should return the top item when sent #pop
# * should remove the top item when sent #pop
# * should complain on #push
# A consumer of a stub
# * should be able to stub methods on any Object
# A stubbed method on a class
# * should return the stubbed value
# * should revert to the original method after each spec
# * can stub! and mock the same message
# A mock
# * can stub!
# * can stub! and mock
# * can stub! and mock the same message
# RSpec should integrate with Test::Unit::TestCase
# * TestCase#setup should be called.
# * RSpec should be able to access TestCase methods
# * RSpec should be able to accept included modules

Finished in 0.030063 seconds

78 examples, 0 failures, 3 pending
