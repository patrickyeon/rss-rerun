require_relative '../lib/fetch.rb'
require 'test/unit'

class FetchUnitTests < Test::Unit::TestCase
    def setup
        f = File.open('test/temp/foo', 'w')
        f.write('foobarbaz')
        f.close
        Fetch.instance.global_sanitize = true
    end

    def test_just_open
        f = Fetch.openUrl('test/temp/foo', false)
        assert_equal 'foobarbaz', f.read
    end

    def test_sanitize_url
        assert_equal 'http://foobar', Fetch.sanitize('foobar')
        assert_equal 'http://foobar', Fetch.sanitize('http://foobar')
        assert_equal 'https://foobar', Fetch.sanitize('https://foobar')
    end

    def test_bypass_sanitize
        Fetch.instance.global_sanitize = false
        f = Fetch.openUrl('test/temp/foo')
        assert_equal 'foobarbaz', f.read
    end

    def test_sanitize_open
        # TODO horrible way to test it, but I've spent too much time trying to
        #  work out the "right way"
        assert_raises SocketError do
            Fetch.openUrl 'test/temp/foo'
        end
    end
end
