
module PuppetTest::Support::Collection
    def run_collection_queries(form)
        {true => [%{title == "/tmp/testing"}, %{(title == "/tmp/testing")}, %{group == bin},
            %{title == "/tmp/testing" and group == bin}, %{title == bin or group == bin},
            %{title == "/tmp/testing" or title == bin}, %{title == "/tmp/testing"},
            %{(title == "/tmp/testing" or title == bin) and group == bin}],
        false => [%{title == bin}, %{title == bin or (title == bin and group == bin)},
            %{title != "/tmp/testing"}, %{title != "/tmp/testing" and group != bin}]
        }.each do |res, ary|
            ary.each do |str|
                if form == :virtual
                    code = "File <| #{str} |>"
                else
                    code = "File <<| #{str} |>>"
                end
                parser = mkparser
                query = nil

                assert_nothing_raised("Could not parse '#{str}'") do
                    query = parser.parse(code).hostclass("").code[0].query
                end

                yield str, res, query
            end
        end
    end
end

