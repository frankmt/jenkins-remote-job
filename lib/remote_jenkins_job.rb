require 'json'
require 'net/https'
require 'open-uri'
require 'uri'

class RemoteJenkinsJob
  def initialize params=[]
    if params.empty?
      puts "Usage: remote_jenkins_job [job uri] ([username] [password])"
    else
      @job_uri = params[0]
      if params[1]
        @basic_auth = [params[1], params[2]]
        @options = {:http_basic_authentication => @basic_auth}
      else
        @options = {}
      end
      start
    end
  end

  private

  def start
    puts "Running remote job: #{@job_uri}"
    original_last_build = get_last_build
    puts "Last build was: " + original_last_build['url'].to_s

    post_build_request

    last_build = original_last_build
    while last_build == original_last_build do
      last_build = get_last_build
      print '.'
      $stdout.flush
      sleep 1
    end

    puts ""
    puts "New build started: #{last_build['url']}"
    while (latest_build = get_new_build(last_build['url']))['building'] do
      print '.'
      $stdout.flush
      sleep 1
    end

    puts ""
    puts "Build result: " + latest_build['result']

    exit(1) unless latest_build['result'] == 'SUCCESS'
  end

  def get_json(url)
    json_url = URI.parse("#{url}#{url[-1] == '/' ? '' : '/'}api/json").to_s
    tries = 5
    begin
      tries -= 1
      return open(URI.parse(json_url).to_s, @options).read
    rescue Timeout::Error => e
      retry if tries > 0
      raise
    end
  end

  private :get_json

  def get_last_build
    JSON.parse(get_json(@job_uri))['lastBuild']
  end

  def get_new_build(url)
    JSON.parse(get_json(url))
  end

  def post_build_request
    proxy_uri = URI.parse(ENV['http_proxy']) if ENV['http_proxy']
    proxy_host, proxy_port = proxy_uri.host, proxy_uri.port if ENV['http_proxy']
    url = URI.parse(@job_uri+'/build')
    use_ssl = true if url.scheme == 'https'
    Net::HTTP::Proxy(proxy_host, proxy_port).start(url.host, url.port, :use_ssl => use_ssl) do |http|
      request = Net::HTTP::Post.new(url.request_uri)
      request.basic_auth @basic_auth[0], @basic_auth[1] if @basic_auth
      http.request(request)
    end
  end
end
