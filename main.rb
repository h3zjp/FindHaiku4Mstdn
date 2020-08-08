require 'bundler/setup'
require 'mastodon'
require 'ikku'
require 'sanitize'
require "./reporter.rb"

debug = true
unfollow_str = "俳句検出を停止してください"

p(ENV["BASE_URL"], ENV["WS_URL"]) if debug

stream = Mastodon::Streaming::Client.new(
  base_url: ENV["WS_URL"] || ENV["BASE_URL"],
  bearer_token: ENV["ACCESS_TOKEN"])

rest = Mastodon::REST::Client.new(
  base_url: ENV["BASE_URL"],
  bearer_token: ENV["ACCESS_TOKEN"])

reporter = Reporter.new

reviewer_id = rest.verify_credentials().id

begin
  stream.user() do |toot|
    if toot.kind_of?(Mastodon::Status) then
      content = Sanitize.clean(toot.content)
      unfollow_request = false
      toot.mentions.each do |mention|
        if mention.id == reviewer_id
          if !content.index(unfollow_str).nil?
            unfollow_request = true
            relationships = rest.relationships([toot.account.id])
            relationships.each do |relationship|
              if relationship.following?
                rest.unfollow(toot.account.id)
                p "unfollow"
              end
            end
          end
        end
      end
      if toot.account.id == reviewer_id then
        p "skip own post" if debug
        next
      end
      if !unfollow_request && (toot.visibility == "public" || toot.visibility == "unlisted") then
        if toot.in_reply_to_id.nil? && toot.attributes["reblog"].nil? then
          p "@#{toot.account.acct}: #{content}" if debug
          songs, reports = reporter.report(content)
          if songs.length > 0 then
            haiku = songs.first
            postcontent = "『#{haiku.phrases[0].join("")} #{haiku.phrases[1].join("")} #{haiku.phrases[2].join("")}』"
            p "俳句検知: #{postcontent}" if debug
            p "tags: #{toot.attributes["tags"]}" if debug
            if toot.attributes["tags"].map{|t| t["name"]}.include?("frfr") then
              postcontent += ' #frfr'
            end
            posted = nil
            if toot.attributes["spoiler_text"].empty? then
              posted = rest.create_status("@#{toot.account.acct} 俳句を発見しました！\n" + postcontent, in_reply_to_id: toot.id)
            else
              posted = rest.create_status("@#{toot.account.acct}\n" + postcontent, in_reply_to_id: toot.id, spoiler_text: "俳句を発見しました！")
            end
            rest.create_status(
              reports,
              visibility: :unlisted,
              in_reply_to_id: posted.id,
            )
            p "post!" if debug
          elsif toot.mentions.any? {|m| m.id == reviewer_id}
            rest.create_status(
              "@#{toot.account.acct}\n" + reports,
              in_reply_to_id: toot.id,
            )
          elsif debug
            p "俳句なし"
          end
        elsif debug
          p "BT or reply"
        end
      elsif debug
        p "private toot"
      end
    elsif toot.kind_of?(Mastodon::Notification) then
      p "#{toot.type} by #{toot.account.id}" if debug
      rest.follow(toot.account.id) if toot.type == "follow"
    end
  end
rescue => e
  p "error", e
  puts e.backtrace
  retry
end
