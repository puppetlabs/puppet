# encoding: UTF-8
shared_examples_for "documentation on faces" do
  context "description" do
    describe "#summary" do
      it "should accept a summary" do
        text = "this is my summary"
        expect { subject.summary = text }.to_not raise_error
        subject.summary.should == text
      end

      it "should accept a long, long, long summary" do
        text = "I never know when to stop with the word banana" + ("na" * 1000)
        expect { subject.summary = text }.to_not raise_error
        subject.summary.should == text
      end

      it "should reject a summary with a newline" do
        expect { subject.summary = "with\nnewlines" }.
          to raise_error ArgumentError, /summary should be a single line/
      end
    end

    describe "#description" do
      it "should accept a description" do
        subject.description = "hello"
        subject.description.should == "hello"
      end

      it "should accept a description with a newline" do
        subject.description = "hello \n my \n fine \n friend"
        subject.description.should == "hello \n my \n fine \n friend"
      end
    end
  end
end
