require_relative '../lib/feed.rb'
require 'test/unit'

class FeedUnitTests < Test::Unit::TestCase
    def posts(feed)
        return Nokogiri::XML(feed).xpath('//item')
    end
    def test_from_mementos
        feed = LocalArchive.fromResource(File.open('test/data/timemap'))
        items = posts(feed)
        assert_equal 8, items.length
        guids = items.collect {|item| Integer(item.at('guid').content)}
        assert_equal Array(1..8).reverse, guids
    end

    def test_create_feed
        f = Feed.fromUrl('test/data/mem2')
        items = posts(f.to_xml)
        guids = items.collect {|item| Integer(item.at('guid').content)}
        assert_equal Array(1..5).reverse, guids
    end

    def test_archive
        # use a local timemap instead of hitting the archive.org servers
        def Archive.fromUrl(url)
            return Archive.fromResource(File.open('test/data/timemap'))
        end

        f = File.open('test/temp/db/index', 'w')
        f.print(Marshal::dump({}))
        f.close
        a = LocalArchive.new('test/temp/db')

        url = 'test/data/original'
        a.create(url)
        assert a.cached?(url)
        assert_equal 8, Nokogiri::XML(a.recall(url)).xpath('//item').length
    end
end
