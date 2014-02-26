require 'spec_helper'

describe Puppet::Util::Docs do

  describe '.scrub' do
    let(:my_cleaned_output) do
      %q{This resource type uses the prescribed native tools for creating
groups and generally uses POSIX APIs for retrieving information
about them.  It does not directly modify `/etc/passwd` or anything.

* Just for fun, we'll add a list.
* list item two,
  which has some add'l lines included in it.

And here's a code block:

    this is the piece of code
    it does something cool

**Autorequires:** I would be listing autorequired resources here.}
    end

    it "strips the least common indent from multi-line strings, without mangling indentation beyond the least common indent" do
      input = <<EOT
        This resource type uses the prescribed native tools for creating
        groups and generally uses POSIX APIs for retrieving information
        about them.  It does not directly modify `/etc/passwd` or anything.

        * Just for fun, we'll add a list.
        * list item two,
          which has some add'l lines included in it.

        And here's a code block:

            this is the piece of code
            it does something cool

        **Autorequires:** I would be listing autorequired resources here.
EOT
      output = Puppet::Util::Docs.scrub(input)
      expect(output).to eq my_cleaned_output
    end

    it "ignores the first line when calculating least common indent" do
      input = "This resource type uses the prescribed native tools for creating
        groups and generally uses POSIX APIs for retrieving information
        about them.  It does not directly modify `/etc/passwd` or anything.

        * Just for fun, we'll add a list.
        * list item two,
          which has some add'l lines included in it.

        And here's a code block:

            this is the piece of code
            it does something cool

        **Autorequires:** I would be listing autorequired resources here."
      output = Puppet::Util::Docs.scrub(input)
      expect(output).to eq my_cleaned_output
    end

    it "strips trailing whitespace from each line, and strips trailing newlines at end" do
      input = "This resource type uses the prescribed native tools for creating  \n        groups and generally uses POSIX APIs for retrieving information \n        about them.  It does not directly modify `/etc/passwd` or anything.  \n\n        * Just for fun, we'll add a list. \n        * list item two,\n          which has some add'l lines included in it.    \n\n        And here's a code block:\n\n            this is the piece of code \n            it does something cool \n\n        **Autorequires:** I would be listing autorequired resources here. \n\n"
      output = Puppet::Util::Docs.scrub(input)
      expect(output).to eq my_cleaned_output
    end

    it "has no side effects on original input string" do
      input       = "First line \n        second line \n        \n            indented line \n        \n        last line\n\n"
      clean_input = "First line \n        second line \n        \n            indented line \n        \n        last line\n\n"
      not_used = Puppet::Util::Docs.scrub(input)
      expect(input).to eq clean_input
    end

    it "does not include whitespace-only lines when calculating least common indent" do
      input           = "First line\n        second line\n  \n            indented line\n\n        last line"
      expected_output = "First line\nsecond line\n\n    indented line\n\nlast line"
      #bogus_output   = "First line\nsecond line\n\n  indented line\n\nlast line"
      output = Puppet::Util::Docs.scrub(input)
      expect(output).to eq expected_output
    end

    it "accepts a least common indent of zero, thus not adding errors when input string is already scrubbed" do
      expect(Puppet::Util::Docs.scrub(my_cleaned_output)).to eq my_cleaned_output
    end

    it "trims leading space from one-liners (even when they're buffered with extra newlines)" do
      input = "
        Updates values in the `puppet.conf` configuration file.
      "
      expected_output = "Updates values in the `puppet.conf` configuration file."
      output = Puppet::Util::Docs.scrub(input)
      expect(output).to eq expected_output
    end


  end
end

