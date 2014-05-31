require_relative '../lib/feed.rb'
require 'test/unit'

class FeedUnitTests < Test::Unit::TestCase
    def setup
        # use a local timemap instead of hitting the archive.org servers
        def Archive.fromUrl(url)
            return Archive.fromResource(File.open('test/data/timemap'))
        end
    end

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

    def test_local_archive
        f = File.open('test/temp/db/index', 'w')
        f.print(Marshal::dump({}))
        f.close
        a = LocalArchive.new('test/temp/db')

        url = 'test/data/original'
        a.create(url)
        assert a.cached?(url)
        assert_equal 8, Nokogiri::XML(a.recall(url)).xpath('//item').length
    end

    def test_total_local_archive
        f = File.open('test/temp/db/index', 'w')
        f.print(Marshal::dump({}))
        f.close
        a = LocalArchive.new('test/temp/db')
        
        url = 'test/data/original'
        a.create(url)
        feed = Feed.fromArchive(url, a)
        assert_equal 10, feed.items.length
        guids = feed.items.collect {|item| Integer(item.at('guid').content)}
        assert_equal Array(1..10), guids
    end

    def test_s3_archive
        a = S3Archive.new(ENV['AMAZON_ACCESS_KEY_ID'],
                          ENV['AMAZON_SECRET_ACCESS_KEY'],
                          ENV['AMAZON_S3_TEST_BUCKET'])
        url = 'test/data/original'
        a.create url
        assert a.cached?(url)
        stored = Nokogiri::XML(a.recall(url))
        assert_equal 8, stored.xpath('//item').length
        assert_equal url, stored.at('url').content
    end

    def test_s3_archive_collide
        a = S3Archive.new(ENV['AMAZON_ACCESS_KEY_ID'],
                          ENV['AMAZON_SECRET_ACCESS_KEY'],
                          ENV['AMAZON_S3_TEST_BUCKET'])
        def a.keyfor(url)
            return 'collide'
        end
        url = 'test/data/original'
        a.create(url)
        assert_equal '', a.recall('foobar')
    end
end