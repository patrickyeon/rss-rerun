require_relative '../lib/feed.rb'
require 'test/unit'

class FeedUnitTests < Test::Unit::TestCase
    def setup
        @proxy = 'http://localhost:8123'
    end

    def test_tah
        feed = Archive.fromUrl('theamphour.com/feed', @proxy)
        puts '%d items from TAH' % Nokogiri::XML(feed).xpath('//item').length
    end
end
