#!/usr/bin/env ruby
require 'nokogiri'
require 'aws/s3'
require_relative 'fetch.rb'

class Feed
    attr_accessor :feed, :items
    
    def self.fromUrl(url)
        return self.fromResource(Fetch.openUrl(url).read)
    end

    def self.fromResource(text)
        feed, items = self.breakup(text)
        return self.new(feed, items)
    end

    def self.breakup(text)
        feed = Nokogiri::XML(text)
        items = feed.xpath('//item').reverse
        items.collect {|item| item.remove}
        return [feed, items]
    end

    def self.fromArchive(url, arc)
        # check if we've got an archived version
        if not arc.cached? url
            arc.create url
        end
        arcitems = Nokogiri::XML(arc.recall url).xpath('//item')
        # bring in the latest
        feed, items = self.breakup(Fetch.openUrl(url).read)
        updated = false
        guids = arcitems.collect {|item| item.at('guid').content}
        # arc + latest > arc?
        items.each do |item|
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

class MementoParsingError < StandardError
    # for when the memento file can't be successfully interpreted
end

class Archive
    def cached?(url)
        raise NotImplementedError
    end
    def update(url, items)
        raise NotImplementedError
    end
    def recall(url)
        raise NotImplementedError
    end

    def create(url)
        feed = Archive.fromUrl(url)
        # TODO avoid jumping back and forth through Nokogiri
        items = Nokogiri::XML(feed).xpath('//item').reverse.to_xml
        self.update(url, items)
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

class LocalArchive < Archive
    def initialize(dir)
        if not dir.end_with?('/')
            dir.concat('/')
        end
        @dir = dir
        f = File.open(dir + 'index')
        @index = Marshal::load(f)
        f.close
        @maxIdx = @index.values.sort[-1] || 0
    end

    def cached?(url)
        return @index.has_key? url
    end

    def update(url, items)
        # items are stored ordered oldest to newest
        # FIXME not safe for multi-process
        if not @index.has_key? url
            @maxIdx += 1
            @index[url] = @maxIdx
            idx = File.open(@dir + 'index', 'w')
            idx.print(Marshal::dump(@index))
            idx.close
        end
        f = File.open('%s%d' % [@dir, @maxIdx], 'w')
        f.print('<xml>' + items + '</xml>')
        f.close
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
end

class S3Archive < Archive
    # TODO all the error conditions
    def initialize(id, secret, bucket)
        AWS::S3::Base.establish_connection!(:access_key_id => id,
                                            :secret_access_key => secret)
        @bucket = AWS::S3::Bucket.find(bucket)
    end

    def cached?(url)
        # gotta do this to update the bucket
        # TODO is there a better way to handle this?
        @bucket = AWS::S3::Bucket.find(@bucket.name)
        return nil != @bucket[keyfor(url)]
    end

    def keyfor(url)
        return Digest::MD5.hexdigest(url)
    end

    def update(url, items)
        AWS::S3::S3Object.store(keyfor(url),
                                '<xml><url>' + url + '</url>' + items + '</xml>',
                                @bucket.name)
    end

    def recall(url)
        if not self.cached? url
            return ''
        end
        
        items = @bucket[keyfor(url)].value
        if not items.start_with?('<xml><url>' + url + '</url>')
            # as a matter of fact, no, collisions aren't handled well
            return ''
        end
        
        return items
    end
end
