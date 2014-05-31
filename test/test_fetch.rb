require_relative '../lib/fetch.rb'
require 'test/unit'

class FetchUnitTests < Test::Unit::TestCase
    def setup
        @fname = 'test/temp/foo'
        @fcont = 'foobarbaz'
        f = File.open(@fname, 'w')
        f.write(@fcont)
        f.close
        Fetch.instance.global_sanitize = true
    end

    def teardown
        Fetch.instance.nil_callback
    end

    def test_just_open
        f = Fetch.openUrl(@fname, false)
        assert_equal @fcont, f.read
    end

    def test_sanitize_url
        assert_equal 'http://foobar', Fetch.sanitize('foobar')
        assert_equal 'http://foobar', Fetch.sanitize('http://foobar')
        assert_equal 'https://foobar', Fetch.sanitize('https://foobar')
    end

    def test_bypass_sanitize
        Fetch.instance.global_sanitize = false
        f = Fetch.openUrl(@fname)
        assert_equal @fcont, f.read
    end

    def test_sanitize_open_and_callback
        cb = lambda do |url|
            assert_equal 'http://' + @fname, url
            return File.open(@fname)
        end
        Fetch.instance.set_callback(&cb)
        f = Fetch.openUrl(@fname)
        assert_equal @fcont, f.read
    end
end
