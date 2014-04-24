require_relative '../lib/rerun.rb'
require_relative '../lib/chrono.rb'
require 'test/unit'
require 'nokogiri'

class RerunUnitTests < Test::Unit::TestCase
    
    def setup
        # arbitrarily, pretend it's Apr 20, 2014 (a Sunday)
        Chrono.instance.set_now DateTime.parse('Sun, Apr 20 2014')

        # build a simple document
        @doc = Nokogiri::XML::Document.parse('''<?xml version="1.0"?>
                                             <rss version="2.0">
                                             </rss></xml>''')
        def addnode(where, name, content=nil)
            elt = Nokogiri::XML::Node.new name, @doc
            if content != nil
                elt.content = content
            end
            where.add_child elt
            return elt
        end

        chan = addnode @doc.at('rss'), 'channel'
        addnode chan, 'title', 'Test RSS feed with ten items'
        addnode chan, 'link', 'http://example.com/ten-items'
        addnode chan, 'description', 'A well-behaved feed with ten items.'

        startDate = DateTime.parse '26 Mar 2014 14:00 GMT'

        for i in (1..10).reverse_each
            item = addnode chan, 'item'
            addnode item, 'title', ('Item ' << i.to_s)
            addnode item, 'link', ('http://example.com/feed/' << i.to_s)
            addnode item, 'pubDate', (startDate + i).rfc822
			addnode item, 'description', 'foo'
        end
    end

    def test_mwf
        # check that a MWF schedule which should have 5 items works
        r = Rerun.new(@doc, startTime = Chrono.now - 12, schedule = '135')
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
