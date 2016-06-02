require 'open-uri'
require 'nokogiri'
require 'rest-client'
require 'optparse'
require 'pry-byebug'

options = {}
OptionParser.new do |opt|
  opt.on('-f TEXTFILE', 'read URLs from textfile') { |v| options[:f] = v }
  opt.parse!(ARGV)
end

url_list = []
if options[:f]
  begin
    File.open(options[:f]) do |file|
      url_list = file.read.split("\n")
      url_list.uniq!
    end
  rescue SystemCallError => e
    puts %(class=[#{e.class}] message=[#{e.message}])
  rescue IOError => e
    puts %(class=[#{e.class}] message=[#{e.message}])
  end
else
  url_list = [ARGV[0]]
end

# NOTE: for staging, please enter user/password below
user     = ''
password = ''

titles = [] # for check dulplicated titles
descriptions = [] # for check dulplicated descriptions

# output headers
puts "url\tline\tcontent\treason"

GOOGLE_UA = 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)'

url_list.each do |url|
  client = RestClient::Resource.new(url, user: user, password: password)

  doc = Nokogiri::HTML(client.get(user_agent: GOOGLE_UA), nil, 'UTF-8')

  hx_nodes = []
  # TSV header 'line depth tagname content'
  # hx_nodes << "line\tdepth\ttagname\tcontent"
  # make node element array(allow duplication)
  doc.traverse do |child|
    # meta name="description"
    if child.element? && child.name =~ /^meta$/ && child[:name] == 'description'
      hx_nodes << [child.line, child.ancestors.size.to_s, 'meta:description', child[:content]]
    end
    # section
    if child.element? && child.name =~ /^section$/
      hx_nodes << [child.line, child.ancestors.size.to_s, child.name.to_s, '']
    end
    # title & hx
    if child.element? && child.name =~ /^h[1-6]$|^title$/
      hx_nodes << [child.line, child.ancestors.size.to_s, child.name.to_s, child.content.to_s.gsub(/\R/, '')]
    end
  end

  tags = []
  hx_nodes.sort!.each do |node|
    # output each tags
    line    = node[0]
    depth   = node[1]
    tagname = node[2]
    content = node[3]

    if tagname == 'meta:description'
      if tags.include? 'meta:description'
        puts "#{url}\t#{line}\t#{content}\tduplicated elements: description"
      end
      descriptions.each do |description|
        if description[:content] == content
          puts "#{url}\t#{line}\t#{content}\tduplicated description content: #{description[:url]}"
        end
      end
      descriptions << { url: url, line: line, content: content }
    elsif tagname == 'title'
      titles.each do |title|
        if title[:content] == content
          puts "#{url}\t#{line}\t#{content}\tduplicated title content: #{title[:url]}"
        end
      end
      titles << { url: url, line: line, content: content }
    elsif tagname == 'h1'
      if tags.include? 'h1'
        puts "#{url}\t#{line}\t#{content}\tduplicated elements: h1"
      end
    elsif tags.last != 'section' # NOTE: skip hx level check with section
      if tagname =~ /^h[1-6]$/
        last_tag_num = tags.last.delete('h').to_i
        tag_num = tagname.delete('h').to_i
        if tag_num - last_tag_num > 1
          puts "#{url}\t#{line}\t#{content}\tskiped elements: h#{last_tag_num} -> h#{tag_num}"
        end
      end
    end
    tags << tagname
    if hx_nodes.last == node
      puts "#{url}\t0\t\ttitle is missing" if titles.empty?
      puts "#{url}\t0\t\tdescription is missing" if descriptions.empty?
    end
  end
end
