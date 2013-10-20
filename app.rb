require 'sinatra'
require 'sequel'
require 'sinatra/sequel'
require 'json'

# Models & migrations

migration 'create links' do
  database.create_table :links do
    primary_key :id
    String :name, :unique => true, :null => false
    String :url, :unique => false, :null => false
    Integer :hits, :default => 0
    DateTime :created_at
    index :name
  end
end

class Link < Sequel::Model
  def hit!
    self.hits += 1
    self.save(:validate => false)
  end

  def validate
    super
    errors.add(:name, 'cannot be empty') if !name || name.empty?
    errors.add(:url, 'cannot be empty') if !url || url.empty?
  end
end


configure do
  set :erb, :escape_html => true
end

# Actions

get '/' do
  @links = Link.order(:hits.desc).all
  erb :index
end

get '/links' do
  redirect '/'
end

post '/links' do
  begin
    Link.create(
      :name => params[:name],
      :url  => params[:url]
    )
    redirect '/'
  rescue Sequel::ValidationFailed,
         Sequel::DatabaseError => e
    halt "Error: #{e.message}"
  end
end

get '/links/suggest' do
  query = params[:q]

  results = Link.filter(:name.like("#{query}%")).or(:url.like("%#{query}%"))
  results = results.all.map {|r| r.name }

  content_type :json
  [query, results].to_json
end

get '/links/search' do
  query = params[:q]
  link  = Link[:name => query]

  if link
    redirect "/#{link.name}"
  else
    @links = Link.filter(:name.like("#{query}%"))
    erb :index
  end
end

get '/links/opensearch.xml' do
  content_type :xml
  erb :opensearch, :layout => false
end

get '/links/:id/remove' do
  link = Link.find(:id => params[:id])
  halt 404 unless link
  link.destroy
  redirect '/'
end

get '/:name/?*?' do
  link = Link[:name => params[:name]]
  halt 404 unless link
  link.hit!

  parts = (params[:splat].first || '').split('/')

  url = link.url
  url %= parts if parts.any?

  redirect url
end

__END__

@@ opensearch
  <OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">
    <ShortName>Go</ShortName>
    <Description>Search Go</Description>
    <InputEncoding>UTF-8</InputEncoding>
    <OutputEncoding>UTF-8</OutputEncoding>
    <Url type="application/x-suggestions+json" method="GET" template="http://go/links/suggest">
      <Param name="q" value="{searchTerms}"/>
    </Url>
    <Url type="text/html" method="GET" template="http://go/links/search">
      <Param name="q" value="{searchTerms}"/>
    </Url>
  </OpenSearchDescription>
