require_relative '../lib/feed.rb'
require_relative '../lib/fetch.rb'
require_relative '../lib/store.rb'
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
        @s3_store = S3Store.new(ENV['AMAZON_ACCESS_KEY_ID'],
                                ENV['AMAZON_SECRET_ACCESS_KEY'],
                                ENV['AMAZON_S3_TEST_BUCKET'])
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

    def test_total_archive
        Fetch.instance.global_canonicalize = false
        a = Archive.new(@s3_store)
        
        url = 'test/data/original'
        a.create(url)
        items = Nokogiri::XML(Feed.new(url, a).recall(-1)).xpath('//item')
        assert_equal 10, items.length
        guids = items.collect {|item| Integer(item.at('guid').content)}
        assert_equal Array(1..10), guids
    end

    def test_s3_archive
        Fetch.instance.global_canonicalize = false
        a = Archive.new(@s3_store)
        url = 'test/data/original'
        a.create url
        assert a.cached?(url)
        stored = Nokogiri::XML(a.recall(url, -1))
        assert_equal 8, stored.xpath('//item').length
    end

    def test_s3_archive_collide
        Fetch.instance.global_canonicalize = false
        a = Archive.new(@s3_store)
        def a.keyfor(url)
            return 'collide'
        end
        url = 'test/data/original'
        a.create(url)
        # this fetch will collide, but it should not return any items.
        stored = Nokogiri::XML(a.recall('foobar', -1))
        assert_equal 0, stored.xpath('//item').length
    end
end

class LargeFeedUnitTests < Test::Unit::TestCase
    def setup
        # use a local timemap instead of hitting the archive.org servers
        def Archive.fromUrl(u)
            cb = lambda do |u|
                return File.open(u[7..-1])
            end
            Fetch.instance.set_callback(&cb)
            return Archive.fromResource(File.open('test/data/puppies.timemap'))
            Fetch.instance.nil_callback
        end

        Fetch.instance.global_canonicalize = false
        @arc = Archive.new(S3Store.new(ENV['AMAZON_ACCESS_KEY_ID'],
                                       ENV['AMAZON_SECRET_ACCESS_KEY'],
                                       ENV['AMAZON_S3_TEST_BUCKET']))
        @url = 'test/data/puppies.rss'
        @arc.create @url
    end

    def min(a, b)
        if a < b
            return a
        else
            return b
        end
    end

    def test_limited_recall
        Array(1..101).each do |i|
            stored = Nokogiri::XML(@arc.recall(@url, i)).xpath('//item')
            assert_equal min(i, 25), stored.length
            assert_equal i, Integer(stored[-1].at('guid').content[3..-1])
        end
    end

    def test_recall_past_end
        [102, 103, 104, 124, 125, 126, 149, 150, 151, 152].each do |i|
            stored = Nokogiri::XML(@arc.recall(@url, i)).xpath('//item')
            assert_equal 25, stored.length
            assert_equal 101, Integer(stored[-1].at('guid').content[3..-1])
        end
    end

end
