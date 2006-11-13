module PuppetTest::FileParsing
    # Run an isomorphism test on our parsing process.
    def fakedataparse(*files)
        files.each do |file|
            oldtarget = @provider.default_target
            cleanup do
                @provider.default_target = oldtarget
            end
            @provider.default_target = file

            assert_nothing_raised("failed to fetch %s" % file) {
                @provider.prefetch
            }

            text = nil
            assert_nothing_raised("failed to generate %s" % file) do 
                text = @provider.to_file(@provider.target_records(file))
            end

            yield if block_given?

            oldlines = File.readlines(file)
            newlines = text.chomp.split "\n"
            oldlines.zip(newlines).each do |old, new|
                assert_equal(old.chomp.gsub(/\s+/, ''), new.gsub(/\s+/, ''),
                    "Lines are not equal in %s" % file)
            end
        end
    end
end

# $Id$
