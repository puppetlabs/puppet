shared_examples_for "an indirector face" do
  [:find, :search, :save, :destroy, :info].each do |action|
    it { should be_action action }
    it { should respond_to action }
  end
end
