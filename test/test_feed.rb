require_relative '../lib/feed.rb'
require 'test/unit'

class FeedUnitTests < Test::Unit::TestCase
    def setup
        @proxy = 'http://localhost:8123'
    end

    def no_test_tah
        feed = Archive.fromUrl('theamphour.com/feed', @proxy)
        puts '%d items from TAH' % Nokogiri::XML(feed).xpath('//item').length
    end

    def no_test_fromurl
        f = Feed.fromUrl('http://theamphour.com/feed')
        puts ' success, %d items' % f.items.length
    end

    def test_archive
        url = 'http://theamphour.com/feed'
        a = Archive.new('data/db')
        a.create(url)
        assert a.cached?(url)
        assert_equal Nokogiri::XML(a.recall(url)).xpath('//item').length, 25
    end
end
