require 'test/unit'

module PuppetTest::FileParsing
  # Run an isomorphism test on our parsing process.
  def fakedataparse(*files)
    files.each do |file|
      @provider.stubs(:default_target).returns(file)

      @provider.prefetch

      text = @provider.to_file(@provider.target_records(file))
      text.gsub!(/^# HEADER.+\n/, '')

      yield if block_given?

      oldlines = File.readlines(file)
      newlines = text.chomp.split "\n"
      oldlines.zip(newlines).each do |old, new|
        if self.is_a?(Test::Unit::TestCase)
          assert_equal(old.chomp.gsub(/\s+/, ''), new.gsub(/\s+/, ''), "File was not written back out correctly")
        else
          new.gsub(/\s+/, '').should == old.chomp.gsub(/\s+/, '')
        end
      end
    end
  end
end

