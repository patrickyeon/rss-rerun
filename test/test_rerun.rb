require_relative '../lib/rerun.rb'
require_relative '../lib/feed.rb'
require_relative '../lib/chrono.rb'
require_relative '../lib/fetch.rb'
require 'test/unit'
require 'nokogiri'

class RerunUnitTests < Test::Unit::TestCase
    
    def setup
        # arbitrarily, pretend it's Apr 20, 2014 (a Sunday)
        Chrono.instance.set_now DateTime.parse('Sun, Apr 20 2014')
        @arc = Archive.new(ENV['AMAZON_ACCESS_KEY_ID'],
                           ENV['AMAZON_SECRET_ACCESS_KEY'],
                           ENV['AMAZON_S3_TEST_BUCKET'])
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
end
