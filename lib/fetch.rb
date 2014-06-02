require 'uri'
require 'open-uri'
require 'singleton'

class Fetch
    include Singleton
    @@g_sanitize = true
    @@g_canonicalize = true
    @@callback = nil

    def initialize
        @@g_sanitize = true
        @@g_canonicalize = true
        @@callback = nil
    end

    # FIXME this callback stuff is shit. Gotta be able to do it better
    # XXX CALLBACKS ARE ONLY FOR TESTING. If you abuse this in non-testing
    #   code, you are a bad bad person.
    def set_callback(&block)
        @@callback = block
    end

    def nil_callback
        @@callback = nil
    end

    def global_sanitize=(truth)
        @@g_sanitize = truth
    end

    def global_canonicalize=(truth)
        @@g_canonicalize = truth
    end

    def self.openUrl(url, sanitize = nil)
        if (sanitize == nil && @@g_sanitize) || sanitize == true
            url = self.sanitize url
        end
        if @@callback != nil
            return @@callback.call(url)
        else
            return self.fetch(url)
        end
    end

    def self.fetch url
        uri = URI.parse(url)
        if [URI::HTTP, URI::HTTPS].include? uri.class
            return uri.open
        end
        return File.open(url)
    end

    def self.sanitize(url)
        if [URI::HTTP, URI::HTTPS].include? URI.parse(url).class
            return url
        else
            return 'http://' + url
        end
    end

    def self.canonicalize(url)
        unless @@g_canonicalize
            return url
        end
        visitedurls, redircount = [], 0
        while redircount < 10 do
            if @@g_sanitize
                url = self.sanitize url
            end
            r = Net::HTTP.get_response(URI.parse(url))
            case r
            when Net::HTTPSuccess then
                return url
            when Net::HTTPRedirection then
                redircount += 1
                visitedurls.push url
                url = r['location']
                if visitedurls.include? url
                    raise RuntimeError.new('Redirection loop: %s' % url)
                end
            else
                raise RuntimeError.new('Fetch error: %s' % url)
            end
        end
        raise RuntimeError.new('Too many redirects')
    end
end
