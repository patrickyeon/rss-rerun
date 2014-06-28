#!/usr/bin/env ruby
require 'nokogiri'
require 'aws-sdk'
require 'json'
require_relative 'fetch.rb'

# Assumptions for this file:
#  o Unless otherwise stated, urls passed to any methods here are safe
#     (sanitized) but not necessarily canonicalized
# TODO make sure that's true

class Feed
    attr_accessor :chan

    def initialize(url, arc)
        # arc is the Archive that stores the history for the url
        if not arc.cached? url
            raise StandardError.new('Feed not archived')
        end

        @url = url
        @arc = arc

        feed = Nokogiri::XML(Fetch.openUrl(url).read)
        items = feed.xpath('//item')
        items.each {|item| item.remove}

        recent_items = Nokogiri::XML(@arc.recall(url, -1)).xpath('//item')
        recent_guid = recent_items[-1].at('guid').content
        new_guids = items.collect {|item| item.at('guid').content}
        cutoff = new_guids.index(recent_guid)
        if cutoff == nil
            cutoff = new_guids.length
        end
        if cutoff > 0
            @arc.update(url, items[0, cutoff])
        end

        @chan = feed
    end

    def recall(loc)
        return @arc.recall(@url, loc)
    end
end

class MementoParsingError < StandardError
    # for when the memento file can't be successfully interpreted
end

class Archive
    # TODO all the error conditions
    def initialize(id, secret, bucket)
        @sess = AWS::S3.new(:access_key_id => id,
                            :secret_access_key => secret)
        @bucket = @sess.buckets[bucket]
    end

    def cached?(url)
        url = Fetch.canonicalize url
        key = keyfor url
        if @bucket.objects.with_prefix(key).count == 0
            return false
        end
        # as a matter of fact, no, collisions aren't handled well
        info = JSON.parse(@bucket.objects[key + '/info.txt'].read)
        return info['url'] == url
    end

    def info(url)
        # TODO some local caching or something to not hit S3 so often
        url = Fetch.canonicalize url
        if not self.cached? url
            return nil
        end

        return JSON.parse(@bucket.objects[keyfor(url) + '/info.txt'].read)
    end

    def keyfor(url)
        url = Fetch.canonicalize url
        return Digest::MD5.hexdigest(url)
    end

    def recall(url, loc)
        info = self.info(url)
        if info == nil
            # that's how we handle collisions for now
            return ''
        end

        if loc > info['item_count'] || loc < 0
            # if they ask past the recent end of the archive, just give 'em the
            #  most recent 25 items
            # negative location is taken to mean "most recent 25"
            return recall url, info['item_count']
        end

        bins = []
        @bucket.objects.with_prefix(keyfor(url)).each {|o| bins.push o}
        bins.keep_if {|o| o.key.end_with?('.items')}
        bins.sort_by! {|o| Integer(/\/0*([0-9]+)/.match(o.key)[1])}
        contained = loc / 25
        if contained == 0
            # special case, we would return up to 25 items, but the requester
            #  is asking for something so early that there aren't 24 previous
            #  items to give them.
            items = bins[0].read
            items = Nokogiri::XML('<x>%s</x>' % items).xpath('//item')
            items = items[0, loc]
        else
            items = bins[contained-1].read
            items << bins[contained].read
            items = Nokogiri::XML('<x>%s</x>' % items).xpath('//item')
            items = items[loc % 25, 25]
        end
        return '<items>%s</items>' % items.to_xml
    end

    def create(url)
        feed = Archive.fromUrl(url)
        # TODO avoid jumping back and forth through Nokogiri
        items = Nokogiri::XML(feed).xpath('//item').reverse

        # for now, just totally clobber anything that was already there
        @bucket.objects.with_prefix(keyfor(url)).each do |o|
            o.delete
        end

        info = {'url' => url, 'item_count' => items.length}
        @bucket.objects[keyfor(url) + '/info.txt'].write(info.to_json)
        (0..(items.length / 25)).each do |i|
            bin = @bucket.objects[keyfor(url) + ('/%d.items' % i)]
            bin.write(items[25 * i, 25].to_xml)
        end
    end

    def update(url, items)
        items = items.reverse
        info = self.info(url)
        binkey = keyfor(url) + '/%d.items'
        last_bin = info['item_count'] / 25
        fill = 25 - (info['item_count'] % 25)
        info['item_count'] = info['item_count'] + items.length
        if fill != 25
            bin = @bucket.objects[binkey % last_bin].read
            bin << items[0, fill].to_xml
            @bucket.objects[binkey % last_bin].write(bin)
        end

        items = items[fill..-1]
        while items != nil && items.length > 0 do
            last_bin += 1
            bin = @bucket.objects[binkey % lastbin]
            bin.write(items[0, 25].to_xml)
            items = items[25..-1]
        end

        @bucket.objects[keyfor(url) + '/info.txt'].write(info.to_json)
    end


    def self.fromUrl(url)
        file = Fetch.openUrl('http://web.archive.org/web/timemap/link/' + url)
        return Archive.fromResource(file)
    end

    def self.fromResource(res)
        links = []
        while not res.eof? do
            temp = res.readline
            if temp.start_with?(' ') or temp.start_with?('\t')
                links[-1] += temp
            else
                links.push temp
            end
        end

        links = links.collect {|link| memento(link)}
        # links is now an array of hashes, each hash is url=>{prop=>[values]}
        links.keep_if { |link| link.values()[0]['rel'][0].split().include?('memento') }
        if not links[-1].values()[0]['rel'][0].split().include?('last')
            raise NotImplementedError.new('Paginated mementos not handled yet')
        end

        items = {}
        guids = []
        links.each do |link|
            memento = Nokogiri::XML(Fetch.openUrl(link.keys()[0]))
            entries = memento.xpath('//item').reverse
            entries.each do |e|
                if e.at('guid') == nil
                    raise NotImplementedError.new('Feeds without GUIDs cannot be cached')
                end
                guid = e.at('guid').content
                if not items.has_key? guid
                    items[guid] = e
                    guids.push(guid)
                end
            end
        end

        # make a new doc with all the items
        guids = guids.reverse()
        total = Nokogiri::XML(Fetch.openUrl(links[0].keys()[0]))
        total.xpath('//item').each do |e|
            e.remove
        end

        chan = total.at('channel')
        guids.each do |guid|
            if chan.children.empty?
                chan.add_child items[guid]
            else
                chan.children.after items[guid]
            end
        end

        return total.to_xml
    end

    def self.dquote(s)
        if s[1] == '"'
            # just easier to deal with here and get rid of it
            return ''
        end

        stop = 0
        while stop != nil do
            stop = s.index(/[\\"]/, stop + 1)
            if s[stop] == '\\'
                # make sure we don't match the escaped character
                stop += 1
            else
                return s[1..(stop - 1)]
            end
        end

        return nil
    end

    def self.memento(link)
        # pretty much just a port of parse_link.py from 
        # https://bitbucket.org/azaroth42/linkheaderparser
        link.strip!
        retval = {}
        uri = ''
        state = :start
        while link.length > 0 do
            if state == :start
                if not link.start_with? '<'
                    raise MementoParsingError.new('< expected at start')
                    return nil
                end
                link = link[1..-1].strip
                state = :uri
            elsif state == :uri
                idx = link.index '>'
                if idx == nil
                    raise MementoParsingError.new('> expected after uri')
                    return nil
                end
                uri = link[0..(idx - 1)]
                retval[uri] = {}
                link = (link[(idx + 1)..-1]).strip
                state = :posturi
            elsif state == :posturi
                if link.start_with? ','
                    state = :start
                elsif link.start_with? ';'
                    state = :linkparam
                else
                    raise MementoParsingError.new(', or ; expected' % link)
                    return nil
                end
                link = link[1..-1].strip
            elsif state == :linkparam
                idx = link.index '='
                if idx == nil
                    raise MementoParsingError.new('param without value' % link)
                    return nil
                end
                param = link[0..(idx - 1)].strip
                if not retval[uri].has_key?(param)
                    retval[uri][param] = []
                end
                link = link[(idx + 1)..-1].strip
                state = :paramvalue
            elsif state == :paramvalue
                if link.start_with? ','
                    state = :start
                    link = link[1..-1]
                elsif link.start_with? ';'
                    state = :linkparam
                    link = link[1..-1]
                elsif link[0] == '"'
                    val = dquote link
                    link = link[(val.length + 2)..-1].strip
                    retval[uri][param].push val
                else
                    idx = link.index(/\s/) || -1
                    val = link[0..idx]
                    link = link[val.length..-1].strip
                    retval[uri][param].push val
                end
                # TODO special case rel ?
            end
        end

        return retval
    end

end
