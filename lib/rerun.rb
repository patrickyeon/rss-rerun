#!/usr/bin/env ruby
require_relative 'chrono.rb'

class Rerun
    
    def initialize(parsedFeed, startTime = nil, schedule = '0123456')
        @feed = parsedFeed
        # TODO fail out if we get a bad feed
        startTime = startTime || Chrono.now
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

        repubDate = @startTime
        count = 0
        entries = @feed.xpath('//item').reverse

        # TODO this needs a lot more logic to work around what happens as we
        #        catch up with the original feed.
        while (repubDate < Chrono.now) and (count < entries.length) do
            if @schedule.include?(repubDate.wday.to_s)
                entry = entries.at(count)

                if entry.at('pubDate') != nil
                    # TODO is this the proper way to use a namespace?
                    odate = Nokogiri::XML::Node.new 'rerun:origDate', @feed
                    odate.content = entry.at('pubDate').to_str
                    entry.add_child odate

                    if entry.at('description') != nil
                        # add a "originally published on" date to the description
                        datestr = "\n<p> Originally published on %s</p>" % odate.content
                        entry.at('description').content += datestr
                    end
                else
                    entry.add_child Nokogiri::XML::Node.new('pubDate', @feed)
                end
                entry.at('pubDate').content = repubDate.rfc822

                count += 1
            end
            repubDate += 1
        end

        # clear out any entries that aren't to be replayed yet
        entries[count .. -1].each do |e|
            e.remove
        end
    end

    def preview_feed
        def _str node_or_nil
            if node_or_nil == nil
                return ''
            else
                return node_or_nil.content
            end
        end
        @feed.xpath('//item').collect {|e| {:title => _str(e.at('title')),
                                            :link => _str(e.at('link')),
                                            :pubDate => _str(e.at('pubDate')),
                                            :origDate => _str(e.at_xpath('rerun:origDate'))}}
    end

    def to_xml
        @feed.to_xml
    end

    private :shift_entries
end
