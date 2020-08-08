require "ikku"

module Ikku
  class Reviewer
    def search_all(text)
      nodes = parser.parse(text)
      [nodes, search(text)]
    end
  end
end

class Reporter
  def initialize
    @reviewer = Ikku::Reviewer.new
  end

  def report(content)
    nodes, songs = @reviewer.search_all(content)

    nodes_desc = nodes.map {|node| "#{node.surface}[#{node.pronunciation}:#{node.pronunciation_length}]" }.join(",")
    songs_desc = songs.map{|s| s.phrases.to_s}.join("\n")

    [
      songs,
      "Nodes: #{nodes_desc}\n" +
      "Songs:\n" +
      "#{songs_desc}\n"
    ]
  end
end
