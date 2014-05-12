#!/usr/bin/env ruby
require 'nokogiri'
require 'open-uri'

class Feed
    def self.fromUrl(url)
        Nokogiri::XML(open(url))
    end
end

class Archive
    def self.fromUrl(url)
        text = open(url)
        links = []
        while not text.eof? do
            temp = text.readline
            if temp.start_with?(' ') or temp.start_with?('\t')
                links[-1] += temp
            else
                links.push temp
            end
        end

        links.collect {|link| memento(link)}
    end

    def self.memento(link)
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
