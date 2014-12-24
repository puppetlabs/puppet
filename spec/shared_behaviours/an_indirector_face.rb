shared_examples_for "an indirector face" do
  [:find, :search, :save, :destroy, :info].each do |action|
    it { is_expected.to be_action action }
    it { is_expected.to respond_to action }
  end
end
