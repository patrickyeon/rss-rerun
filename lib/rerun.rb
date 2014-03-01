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
    end

    def shift_entries
        if DateTime.now < @startTime
            return []
        end

        # make sure we have our namespace here
        unless @feed.root.namespaces.key('xmlns:rerun')
            # TODO find a real URL for the namespace to point to
            @feed.root.add_namespace_definition('rerun', 'todo://put.in/a/URL.here')
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
				#      make the changes only once, no matter how often called
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

end
