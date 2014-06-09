require_relative '../lib/feed.rb'
require_relative '../lib/fetch.rb'
require 'test/unit'

class FeedUnitTests < Test::Unit::TestCase
    def setup
        # use a local timemap instead of hitting the archive.org servers
        def Archive.fromUrl(url)
            cb = lambda do |url|
                return File.open(url[7..-1])
            end
            Fetch.instance.set_callback(&cb)
            return Archive.fromResource(File.open('test/data/timemap'))
            Fetch.instance.nil_callback
        end
    end

    def teardown
        # make sure none of this bleeds over between tests
        Fetch.instance.global_sanitize = true
        Fetch.instance.global_canonicalize = true
        Fetch.instance.nil_callback
    end

    def posts(feed)
        return Nokogiri::XML(feed).xpath('//item')
    end

    def test_from_mementos
        Fetch.instance.global_sanitize = false
        feed = Archive.fromResource(File.open('test/data/timemap'))
        Fetch.instance.global_sanitize = true
        items = posts(feed)
        assert_equal 8, items.length
        guids = items.collect {|item| Integer(item.at('guid').content)}
        assert_equal Array(1..8).reverse, guids
    end

    def test_create_feed
        Fetch.instance.global_sanitize = false
        f = Feed.fromUrl('test/data/mem2')
        Fetch.instance.global_sanitize = true
        items = posts(f.to_xml)
        guids = items.collect {|item| Integer(item.at('guid').content)}
        assert_equal Array(1..5).reverse, guids
    end

    def test_total_archive
        Fetch.instance.global_canonicalize = false
        a = Archive.new(ENV['AMAZON_ACCESS_KEY_ID'],
                        ENV['AMAZON_SECRET_ACCESS_KEY'],
                        ENV['AMAZON_S3_TEST_BUCKET'])
        
        url = 'test/data/original'
        a.create(url)
        feed = Feed.fromArchive(url, a)
        assert_equal 10, feed.items.length
        guids = feed.items.collect {|item| Integer(item.at('guid').content)}
        assert_equal Array(1..10), guids
    end

    def test_s3_archive
        Fetch.instance.global_canonicalize = false
        a = Archive.new(ENV['AMAZON_ACCESS_KEY_ID'],
                        ENV['AMAZON_SECRET_ACCESS_KEY'],
                        ENV['AMAZON_S3_TEST_BUCKET'])
        url = 'test/data/original'
        a.create url
        assert a.cached?(url)
        stored = Nokogiri::XML(a.recall(url))
        assert_equal 8, stored.xpath('//item').length
    end

    def test_s3_archive_collide
        Fetch.instance.global_canonicalize = false
        a = Archive.new(ENV['AMAZON_ACCESS_KEY_ID'],
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
