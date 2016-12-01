require 'elasticsearch'
require 'json'
require 'parallel'

class Hash
  def slice(*keys)
    keys.map! { |key| convert_key(key) } if respond_to?(:convert_key, true)
    keys.each_with_object(self.class.new) { |k, hash| hash[k] = self[k] if has_key?(k) }
  end
end

transport = Elasticsearch::Transport::Transport::HTTP::Faraday.new(
  hosts: [{
    scheme: 'https',
    host: "search-govuk-content-test-rcuwaffc5v3fdv432u64mcxvpu.us-east-1.es.amazonaws.com",
    port: '443',
  }]
)

client = Elasticsearch::Client.new(transport: transport)

begin
  client.indices.delete(index: 'content-items')
rescue
end

# https://www.elastic.co/guide/en/elasticsearch/guide/current/mapping-intro.html

IDENTIFIER = {
  type: "string",
  index: "not_analyzed",
}

DATE = {
  type: "date",
  index: "not_analyzed",
}

TEXT = {
  type: "string",
  index: "analyzed",
}

MAPPINGS = {
  title: TEXT,
  description: TEXT,
  content_id: IDENTIFIER,
  rendering_app: IDENTIFIER,
  publishing_app: IDENTIFIER,
  document_type: IDENTIFIER,
  schema_name: IDENTIFIER,
  locale: IDENTIFIER,
  base_path: IDENTIFIER,
}

client.indices.create(
  index: 'content-items',
  body: {
    mappings: {
      page: {
        properties: MAPPINGS
      }
    }
  }
)

done = 0

Parallel.each(Dir.glob("items/*.json"), in_threads: 50) do |filename|
  begin
    content_item = JSON.parse(File.read(filename))
  rescue
    next
  end

  # Only insert things that we've typed
  payload = content_item.slice(*MAPPINGS.keys.map(&:to_s))

  client.index(
    index: 'content-items',
    type: 'page',
    id: payload["content_id"],
    body: payload,
  )

  done = done + 1

  puts "#{done} Indexed #{payload["base_path"]}"
end

client.indices.refresh(index: 'content-items')
