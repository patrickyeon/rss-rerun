#!/usr/bin/env ruby
require 'feedzirra'

# TODO how to do this for all Parsers, preferrably without iterating by hand
class Feedzirra::Parser::ITunesRSSItem
    attr_accessor :original_published

    def override_published(val)
        @published = val
    end
end

class Rerun
    
    def initialize(url, startTime = nil, schedule = '0123456')
        @url = url
        @feed = Feedzirra::Feed.fetch_and_parse(url)
        # TODO fail out if fetch fails
        startTime = startTime or DateTime.now
        @startTime = DateTime.new(startTime.year, startTime.month, startTime.day)
        @schedule = schedule
    end

    def entries_shifted
        if DateTime.now < @startTime
            return []
        end

        oneday = 1 #24 * 60 * 60
        repubDate = @startTime
        count = 0
        entries = @feed.entries.reverse

        # TODO this needs a lot more logic to work around what happens as we
        #        catch up with the original feed.
        while (repubDate < DateTime.now) and (count < entries.length) do
            if @schedule.include?(repubDate.wday.to_s)
                entries.at(count).original_published = entries.at(count).published
                entries.at(count).override_published(repubDate.rfc822)
                count += 1
            end
            repubDate = repubDate + oneday
        end

        return entries[0,count].reverse
    end
end
