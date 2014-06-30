#!/usr/bin/env ruby
require_relative 'chrono.rb'

class Rerun
    
    def initialize(parsedFeed, startTime = nil, schedule = '0123456')
        @feed = parsedFeed
        # TODO fail out if we get a bad feed
        startTime = startTime || Chrono.now
        @startTime = DateTime.new(startTime.year, startTime.month, startTime.day)
        @schedule = schedule
        unless @feed.chan.root.namespaces.key('xmlns:rerun')
            # TODO find a real URL for the namespace to point to
            @feed.chan.root.add_namespace_definition('rerun',
                                                     'https://github.com/patrickyeon/rerun-rss')
        end
    end

    def shifted
        if Chrono.now < @startTime
            return nil
        end

        repubDate = @startTime
        dates = []
        while (repubDate < Chrono.now) do
            if @schedule.include?(repubDate.wday.to_s)
                dates.push(repubDate)
            end
            repubDate += 1
        end

        items = Nokogiri::XML(@feed.recall(dates.length)).xpath('//item').reverse
        items.zip(dates.reverse) do |item, date|
            unless date == nil
                if item.at('pubDate') != nil
                    odate = Nokogiri::XML::Node.new('rerun:origDate', @feed.chan)
                    # TODO should this be .content instead?
                    odate.content = item.at('pubDate').to_str
                    item.add_child(odate)
                    if item.at('description') != nil
                        # add a "originally published on" date to the description
                        datestr = "\n<p> Originally published on %s</p>" % odate.content
                        item.at('description').content += datestr
                    end
                    item.at('pubDate').content = date.rfc822
                else
                    pdate = Nokogiri::XML::Node.new('pubDate', @feed.chan)
                    pdate.content = date.rfc822
                    item.add_child(pdate)
                end
            end
        end

        return items
    end

    def preview_feed
        def _str node_or_nil
            if node_or_nil == nil
                return ''
            else
                return node_or_nil.content
            end
        end
        shifted.collect { |e|
            {:title => _str(e.at('title')),
            :link => _str(e.at('link')),
            :pubDate => _str(e.at('pubDate')),
            # namespacing buggers things up
            #:origDate => _str(e.at_xpath('//rerun:origDate'))}}
            :origDate => _str(e.children.select {
                |node| node.name == 'rerun:origDate'}[0])}
        }
    end

    def to_xml
        ret = @feed.chan.clone
        items = shifted
        chan = ret.at('channel')
        if chan.children.empty?
            chan.add_child(items[0])
        else
            chan.children.after(items[0])
        end

        items[1..-1].each {|item| chan.children.after(item)}
        return ret.to_xml
    end
end
