#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet'
require 'puppet/type/schedule'
require 'puppettest'

class TestSchedule < Test::Unit::TestCase
    include PuppetTest

    def setup
        super
        @stype = Puppet::Type::Schedule

        # This will probably get overridden by different tests
        @now = Time.now
        Puppet[:ignoreschedules] = false
    end

    def mksched
        s = nil
        assert_nothing_raised {
            s = @stype.create(
                :name => "testsched"
            )
        }

        s
    end

    def diff(unit, incr, method, count)
        diff = @now.to_i.send(method, incr * count)
        t = Time.at(diff)

        #Puppet.notice "%s: %s %s %s = %s" %
        #    [unit, @now.send(unit), method, count, t]
        #t.strftime("%H:%M:%S")
        t
    end

    def month(method, count)
        diff(:hour, 3600 * 24 * 30, method, count)
    end

    def week(method, count)
        diff(:hour, 3600 * 24 * 7, method, count)
    end

    def day(method, count)
        diff(:hour, 3600 * 24, method, count)
    end

    def hour(method, count)
        diff(:hour, 3600, method, count)
    end

    def min(method, count)
        diff(:min, 60, method, count)
    end

    def sec(method, count)
        diff(:sec, 1, method, count)
    end

    def settimes
        unless defined? @@times
            @@times = [Time.now]

            # Make one with an edge year on each side
            ary = Time.now.to_a
            [1999, 2000, 2001].each { |y|
                ary[5] = y; @@times << Time.local(*ary)
            }

            # And with edge hours
            ary = Time.now.to_a
            #[23, 0].each { |h| ary[2] = h; @@times << Time.local(*ary) }
            # 23 hour
            ary[2] = 23
            @@times << Time.local(*ary)
            # 0 hour, next day
            ary[2] = 0
            @@times << addday(Time.local(*ary))

            # And with edge minutes
            #[59, 0].each { |m| ary[1] = m; @@times << Time.local(*ary) }
            ary = Time.now.to_a
            ary[1] = 59; @@times << Time.local(*ary)
            ary[1] = 0
            #if ary[2] == 23
                @@times << Time.local(*ary)
            #else
            #    @@times << addday(Time.local(*ary))
            #end
        end

        Puppet.err @@times.inspect

        @@times.each { |time|
            @now = time
            yield time
        }

        @now = Time.now
    end

    def test_range
        s = mksched

        ary = @now.to_a
        ary[2] = 12
        @now = Time.local(*ary)
        data = {
            true => [
                # An hour previous, an hour after
                [hour("-", 1), hour("+", 1)],

                # an hour previous but a couple minutes later, and an hour plus
                [min("-", 57), hour("+", 1)]
            ],
            false => [
                # five minutes from now, an hour from now
                [min("+", 5), hour("+", 1)],

                # an hour ago, 20 minutes ago
                [hour("-", 1), min("-", 20)]
            ]
        }

        data.each { |result, values|
            values = values.collect { |value|
                "%s - %s" % [value[0].strftime("%H:%M:%S"),
                    value[1].strftime("%H:%M:%S")]
            }
            values.each { |value|
                assert_nothing_raised("Could not parse %s" % value) {
                    s[:range] = value
                }

                assert_equal(result, s.match?(nil, @now),
                    "%s matched %s incorrectly" % [value.inspect, @now])
            }

            assert_nothing_raised("Could not parse %s" % [values]) {
                s[:range] = values
            }

            assert_equal(result, s.match?(nil, @now),
                "%s matched %s incorrectly" % [values.inspect, @now])
        }
    end

    def test_period_by_distance
        previous = @now

        s = mksched

        assert_nothing_raised {
            s[:period] = :daily
        }

        assert(s.match?(day("-", 1)), "did not match minus a day")
        assert(s.match?(day("-", 2)), "did not match two days")
        assert(! s.match?(@now), "matched today")
        assert(! s.match?(hour("-", 11)), "matched minus 11 hours")

        # Now test hourly
        assert_nothing_raised {
            s[:period] = :hourly
        }

        assert(s.match?(hour("-", 1)), "did not match minus an hour")
        assert(s.match?(hour("-", 2)), "did not match two hours")
        assert(! s.match?(@now), "matched now")
        assert(! s.match?(min("-", 59)), "matched minus 11 hours")

        # and weekly
        assert_nothing_raised {
            s[:period] = :weekly
        }

        assert(s.match?(week("-", 1)), "did not match minus a week")
        assert(s.match?(day("-", 7)), "did not match minus 7 days")
        assert(s.match?(day("-", 8)), "did not match minus 8 days")
        assert(s.match?(week("-", 2)), "did not match two weeks")
        assert(! s.match?(@now), "matched now")
        assert(! s.match?(day("-", 6)), "matched minus 6 days")

        # and monthly
        assert_nothing_raised {
            s[:period] = :monthly
        }

        assert(s.match?(month("-", 1)), "did not match minus a month")
        assert(s.match?(week("-", 5)), "did not match minus 5 weeks")
        assert(s.match?(week("-", 7)), "did not match minus 7 weeks")
        assert(s.match?(day("-", 50)), "did not match minus 50 days")
        assert(s.match?(month("-", 2)), "did not match two months")
        assert(! s.match?(@now), "matched now")
        assert(! s.match?(week("-", 3)), "matched minus 3 weeks")
        assert(! s.match?(day("-", 20)), "matched minus 20 days")
    end

    # A shortened test...
    def test_period_by_number
        s = mksched
        assert_nothing_raised {
            s[:periodmatch] = :number
        }

        assert_nothing_raised {
            s[:period] = :daily
        }

        assert(s.match?(day("+", 1)), "didn't match plus a day")
        assert(s.match?(week("+", 1)), "didn't match plus a week")
        assert(! s.match?(@now), "matched today")
        assert(! s.match?(hour("-", 1)), "matched minus an hour")
        assert(! s.match?(hour("-", 2)), "matched plus two hours")

        # Now test hourly
        assert_nothing_raised {
            s[:period] = :hourly
        }

        assert(s.match?(hour("+", 1)), "did not match plus an hour")
        assert(s.match?(hour("+", 2)), "did not match plus two hours")
        assert(! s.match?(@now), "matched now")
        assert(! s.match?(sec("+", 20)), "matched plus 20 seconds")
    end

    def test_periodmatch_default
        s = mksched

        match = s[:periodmatch]
        assert(match, "Could not find periodmatch")

        assert_equal(:distance, match, "Periodmatch was %s" % match)
    end

    def test_scheduled_objects
        s = mksched
        s[:period] = :hourly

        f = nil
        path = tempfile()
        assert_nothing_raised {
            f = Puppet.type(:file).create(
                :name => path,
                :schedule => s.name,
                :ensure => "file"
            )
        }

        assert(f.scheduled?, "File is not scheduled to run")

        assert_apply(f)

        assert(! f.scheduled?, "File is scheduled to run already")
        File.unlink(path)

        assert_apply(f)

        assert(! FileTest.exists?(path), "File was created when not scheduled")
    end

    def test_latebinding_schedules
        f = nil
        path = tempfile()
        assert_nothing_raised {
            f = Puppet.type(:file).create(
                :name => path,
                :schedule => "testsched",
                :ensure => "file"
            )
        }

        s = mksched
        s[:period] = :hourly

        assert_nothing_raised {
            f.schedule
        }

        assert(f.scheduled?, "File is not scheduled to run")
    end

    # Verify that each of our default schedules exist
    def test_defaultschedules
        Puppet.type(:schedule).mkdefaultschedules
        %w{puppet hourly daily weekly monthly}.each { |period|
            assert(Puppet.type(:schedule)[period], "Could not find %s schedule" %
                period)
        }
    end

    def test_period_with_repeat
        previous = @now

        s = mksched
        s[:period] = :hourly

        assert_nothing_raised("Was not able to set periodmatch") {
            s[:periodmatch] = :number
        }
        assert_raise(Puppet::Error) {
            s[:repeat] = 2
        }
        assert_nothing_raised("Was not able to reset periodmatch") {
            s[:periodmatch] = :distance
        }

        assert(! s.match?(min("-", 40)), "matched minus 40 minutes")

        assert_nothing_raised("Was not able to set period") {
            s[:repeat] = 2
        }

        assert(! s.match?(min("-", 20)), "matched minus 20 minutes with half-hourly")
        assert(s.match?(min("-", 40)), "Did not match minus 40 with half-hourly")

        assert_nothing_raised("Was not able to set period") {
            s[:repeat] = 3
        }

        assert(! s.match?(min("-", 15)), "matched minus 15 minutes with half-hourly")
        assert(s.match?(min("-", 25)), "Did not match minus 25 with half-hourly")
    end
end

# $Id$
