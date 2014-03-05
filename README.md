rss-rerun
=========
rss-rerun is meant to act as a shim in between an RSS feed and your reader of choice. The initial target use is podcast listeners who may have discovered a new podcast and want to catch up through the old episodes before working on the new stuff. The idea is that the user sets a schedule to re-broadcast the initial content (at a higher rate than the original publishing schedule), and can catch up at a reasonably accelerated rate without all-out binging on the podcast and have it all managed seamlessly.

rss-rerun is a Sinatra app with nothing especially fancy, which means you can start it up with `ruby lib/app.rb` and hit the home page at `http://localhost:4567/`.

There's a rough roadmap in `TODO`.
