#!/usr/bin/env ruby
require 'nokogiri'
require 'open-uri'

class Rerun
    
    def initialize(url, startTime = nil, schedule = '0123456')
        @url = url
        @feed = Nokogiri::XML(open(url))
        # TODO fail out if fetch fails
        startTime = startTime || DateTime.now
        @startTime = DateTime.new(startTime.year, startTime.month, startTime.day)
        @schedule = schedule
        shift_entries
    end

    def shift_entries
        # TODO make sure this only happens once. For now, it's just a private
        #        method and we call it during initialization

        if DateTime.now < @startTime
            @feed.xpath('//item').each {|e| e.remove}
            return
        end

        # make sure we have our namespace here
        unless @feed.root.namespaces.key('xmlns:rerun')
            # TODO find a real URL for the namespace to point to
            @feed.root.add_namespace_definition('rerun',
                                                'https://github.com/patrickyeon/rerun-rss')
        end

        oneDay = 1
        repubDate = @startTime
        count = 0
        entries = @feed.xpath('//item').reverse

        # TODO this needs a lot more logic to work around what happens as we
        #        catch up with the original feed.
        while (repubDate < DateTime.now) and (count < entries.length) do
            if @schedule.include?(repubDate.wday.to_s)
				entry = entries.at(count)
				# TODO is this the proper way to use a namespace?
				odate = Nokogiri::XML::Node.new 'rerun:origDate', @feed
				odate.content = entry.at('pubDate').to_str
				entry.at('pubDate').add_next_sibling odate
				entry.at('pubDate').content = repubDate

				# add a "originally published on" date to the description
				datestr = "\n<p> Originally published on " << odate.content << '</p>'
				entry.at('description').content = entry.at('description').content + datestr
                count += 1
            end
            repubDate = repubDate + oneDay
        end

        entries[count .. -1].each do |e|
            e.remove
        end
    end

    def preview_feed
        @feed.xpath('//item').collect {|e| [e.at('title').content,
                                            e.at('pubDate').content,
                                            e.at_xpath('rerun:origDate').content]}
    end

    def to_xml
        @feed.to_xml
    end

    private :shift_entries
end
