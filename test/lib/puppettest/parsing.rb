module PuppetTest::Parsing
    # Run an isomorphism test on our parsing process.
    def fakedataparse(file)
        @provider.path = file
        instances = nil
        assert_nothing_raised {
            instances = @provider.retrieve
        }

        text = @provider.fileobj.read

        yield if block_given?

        dest = tempfile()
        @provider.path = dest

        # Now write it back out
        assert_nothing_raised {
            @provider.store(instances)
        }

        newtext = @provider.fileobj.read

        # Don't worry about difference in whitespace
        assert_equal(text.gsub(/\s+/, ' '), newtext.gsub(/\s+/, ' '))
    end
end

# $Id$
