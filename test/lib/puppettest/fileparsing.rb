module PuppetTest::FileParsing
    # Run an isomorphism test on our parsing process.
    def fakedataparse(file)
        oldtarget = @provider.default_target
        cleanup do
            @provider.default_target = oldtarget
        end
        @provider.default_target = file

        assert_nothing_raised {
            @provider.prefetch
        }

        text = @provider.to_file(@provider.target_records(file))

        yield if block_given?

        oldlines = File.readlines(file)
        newlines = text.chomp.split "\n"
        oldlines.zip(newlines).each do |old, new|
            assert_equal(old.chomp.gsub(/\s+/, ''), new.gsub(/\s+/, ''),
                "Lines are not equal")
        end
    end
end

# $Id$
