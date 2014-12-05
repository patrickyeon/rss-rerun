require_relative '../lib/rerun.rb'
require_relative '../lib/feed.rb'
require_relative '../lib/chrono.rb'
require_relative '../lib/fetch.rb'
require_relative '../lib/store.rb'
require 'test/unit'
require 'nokogiri'

class RerunUnitTests < Test::Unit::TestCase
    
    def setup
        # arbitrarily, pretend it's Apr 20, 2014 (a Sunday)
        Chrono.instance.set_now DateTime.parse('Sun, Apr 20 2014')

        @arc = Archive.new(S3Store.new(ENV['AMAZON_ACCESS_KEY_ID'],
                                       ENV['AMAZON_SECRET_ACCESS_KEY'],
                                       ENV['AMAZON_S3_TEST_BUCKET']))
    end

    def test_mwf
        # use a local timemap instead of hitting the archive.org servers
        def Archive.fromUrl(url)
            cb = lambda do |url|
                return File.open(url[7..-1])
            end
            Fetch.instance.set_callback(&cb)
            return Archive.fromResource(File.open('test/data/simple.timemap'))
            Fetch.instance.nil_callback
        end
        Fetch.instance.global_canonicalize = false
        url = 'test/data/simple.rss'
        @arc.create(url)

        # check that a MWF schedule which should have 5 items works
        feed = Feed.new(url, @arc)
        r = Rerun.new(feed, startTime = Chrono.now - 12, schedule = '135')
        items = Nokogiri::XML(r.to_xml).xpath('//item')
        assert_equal 5, items.length
        for day, it in [18, 16, 14, 11, 9].zip(items)
            date = DateTime.parse(it.at('pubDate').to_str)
            assert_equal 2014, date.year
            assert_equal 4, date.month
            assert_equal day, date.day
        end
    end

    def test_no_pubdate
        # use a local timemap instead of hitting the archive.org servers
        def Archive.fromUrl(url)
            cb = lambda do |url|
                return File.open(url[7..-1])
            end
            Fetch.instance.set_callback(&cb)
            return Archive.fromResource(File.open('test/data/simple-nopub.timemap'))
            Fetch.instance.nil_callback
        end
        Fetch.instance.global_canonicalize = false
        url = 'test/data/simple-nopub.rss'
        @arc.create(url)

        feed = Feed.new(url, @arc)
        r = Rerun.new(feed, startTime = Chrono.now - 12, schedule = '135')
        items = Nokogiri::XML(r.to_xml).xpath('//item')
        assert_equal 5, items.length
        for day, it in [18, 16, 14, 11, 9].zip(items)
            date = DateTime.parse(it.at('pubDate').to_str)
            assert_equal 2014, date.year
            assert_equal 4, date.month
            assert_equal day, date.day
        end
    end

    def test_passthrough
        # use a local timemap instead of hitting the archive.org servers
        def Archive.fromUrl(url)
            cb = lambda do |url|
                return File.open(url[7..-1])
            end
            Fetch.instance.set_callback(&cb)
            return Archive.fromResource(File.open('test/data/simple-weekly.timemap'))
            Fetch.instance.nil_callback
        end
        Fetch.instance.global_canonicalize = false
        url = 'test/data/simple-weekly.rss'
        @arc.create(url)

        feed = Feed.new(url, @arc)
        r = Rerun.new(feed, startTime = Date.parse('2014-03-02',
                                                   schedule = '1234567'))
        # so it should re-broadcast items 1-5, and then pass-through the rest
        items = Nokogiri::XML(r.to_xml).xpath('//item')
        assert_equal 10, items.length
        cases = [5, 29, 22, 15, 8, 7, 6, 5, 4, 3].zip(items)
        # special-case the first one, as month is different
        date = DateTime.parse(cases[0][1].at('pubDate').to_str)
        assert_equal 2014, date.year
        assert_equal 4, date.month
        assert_equal 5, date.day
        for day, it in cases[1..-1]
            date = DateTime.parse(it.at('pubDate').to_str)
            assert_equal 2014, date.year
            assert_equal 3, date.month
            assert_equal day, date.day
        end
    end
end
