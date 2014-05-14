#!/usr/bin/env ruby
require 'nokogiri'
require 'open-uri'

class Feed
    attr_accessor :feed, :items
    
    def self.fromUrl(url)
        feed, items = self.breakup(url)
        return self.new(feed, items)
    end

    def self.breakup(url)
        feed = Nokogiri::XML(open(url))
        items = feed.xpath('//item').reverse
        items.collect {|item| item.remove}
        return [feed, items]
    end

    def self.fromArchive(url, arc)
        # check if we've got an archived version
        if not arc.cached? url
            arc.create url
        end
        arcitems = Nokogiri::XML(arc.recall url)
        # bring in the latest
        feed, items = self.breakup(url)
        updated = false
        guids = arcitems.collect {|item| item.at('guid').content}
        # arc + latest > arc?
        items.reverse.each do |item|
            if not guids.include? item.at('guid').content
                arcitems.push item
                updated = true
            end
        end
        if updated
            arc.update(url, arcitems.to_xml)
        end

        return self.new(feed, arcitems)
    end

    def initialize(emptyfeed, items)
        # items must be ordered oldest to newest
        @feed = emptyfeed
        @items = items
    end

    def to_xml
        retval = @feed.clone
        chan = retval.at('channel')
        @items.reverse.each do |item|
            chan.add_child item
        end
        return retval.to_xml
    end

end

class Archive

    def initialize(dir)
        if not dir.end_with?('/')
            dir.concat('/')
        end
        @dir = dir
        @index = Marshal::load(File.open(dir + 'index'))
        @maxIdx = @index.values.sort[-1] || 0
    end

    def cached?(url)
        return @index.has_key? url
    end

    def update(url, items)
        # items are stored ordered oldest to newest
        if not @index.has_key? url
            @maxIdx += 1
            @index[url] = @maxIdx
        end
        f = File.open('%s%d' % [@dir, @maxIdx], 'w')
        f.print('<xml>' + items + '</xml>')
        f.close
    end

    def create(url)
        feed = Archive.fromUrl(url)
        # TODO avoid jumping back and forth through Nokogiri
        items = Nokogiri::XML(feed).xpath('//item').reverse.to_xml
        self.update(url, items)
    end

    def recall(url)
        if not self.cached? url
            return ''
        end

        f = File.open('%s%d' % [@dir, @index[url]])
        items = f.read
        f.close
        return items
    end

    def self.fromUrl(url, proxy=nil)
        text = open('http://web.archive.org/web/timemap/link/' + url,
                    :proxy=>proxy)
        links = []
        while not text.eof? do
            temp = text.readline
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
            raise NameError.new('paginated rss feed')
        end

        items = {}
        guids = []
        links.each do |link|
            memento = Nokogiri::XML(open(link.keys()[0]))
            entries = memento.xpath('//item').reverse
            entries.each do |e|
                if e.at('guid') == nil
                    raise NameError.new('entry has no guid')
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
        total = Nokogiri::XML(open(links[0].keys()[0]))
        total.xpath('//item').each do |e|
            e.remove
        end

        chan = total.at('channel')
        guids.each do |guid|
            chan.add_child items[guid]
        end

        return total.to_xml

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
                    raise NameError.new('start %s' % link)
                    return nil
                end
                link = link[1..-1].strip
                state = :uri
            elsif state == :uri
                idx = link.index '>'
                if idx == nil
                    raise NameError.new('uri %s' % link)
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
                    raise NameError.new('posturi %s' % link)
                    return nil
                end
                link = link[1..-1].strip
            elsif state == :linkparam
                idx = link.index '='
                if idx == nil
                    raise NameError.new('linkparam %s' % link)
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
end
