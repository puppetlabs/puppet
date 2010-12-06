require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PuppetTest::RunnableTest do
  before do
    @runnable_test = Class.new.extend(PuppetTest::RunnableTest)
  end

  describe "#confine" do
    subject { @runnable_test }

    it "should accept a hash" do
      subject.confine({}).should_not raise_error(ArgumentError)
    end

    it "should accept a message and a block" do
      subject.confine(""){}.should_not raise_error(ArgumentError)
    end

  end

  describe "#runnable?" do
    describe "when the superclass is not runnable" do
      before { @runnable_test.stubs(:superclass).returns(stub("unrunnable superclass", :runnable? => false)) }
      subject { @runnable_test.runnable? }

      it { should be_false }
    end

    describe "when a confine is false" do
      before { @runnable_test.confine(:message => false) }
      subject { @runnable_test.runnable? }

      it { should be_false }
    end

    describe "when a confine has a block that returns false" do
      before { @runnable_test.confine(:message){ false } }
      subject { @runnable_test.runnable? }

      it { should be_false }
    end

    describe "when a confine is true and no false confines" do
      before { @runnable_test.confine(:message => true) }
      subject { @runnable_test.runnable? }

      it { should be_true }
    end

    describe "when a confine has block that returns true and no false confines" do
      before { @runnable_test.confine(:message){ true } }
      subject { @runnable_test.runnable? }

      it { should be_true }
    end

  end

  describe "#messages" do
    describe "before runnable? is called" do
      subject { @runnable_test.messages }

      it { should == [] }
    end

    describe "when runnable? is called and returns false" do
      before do
        @runnable_test.confine(:message => false)
        @runnable_test.runnable?
      end

      subject { @runnable_test.messages }

      it "should include the failed confine's message" do
        should include(:message)
      end

    end

    describe "when runnable? is called whose block returns false" do
      before do
        @runnable_test.confine(:message){ false }
        @runnable_test.runnable?
      end

      subject { @runnable_test.messages }

      it "should include the failed confine's message" do
        should include(:message)
      end

    end

  end
end
