require 'open-uri'
require 'nokogiri'
require 'rest-client'

url = ARGV[0]

# NOTE: for staging, please enter user/password below
user     = ''
password = ''

if user.empty? && password.empty?
  client = RestClient::Resource.new(url, user: user, password: password)
else
  client = RestClient::Resource.new(url)
end

doc = Nokogiri::HTML(client.get(user_agent: 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)'), nil, 'UTF-8')

charset = nil

# puts "title\t" + doc.title

hx_nodes = []
# TSVのヘッダ line depth tagname content
# hx_nodes << "line\tdepth\ttagname\tcontent"
# 要素ノード名を重複を許して配列にする
doc.traverse do |child|
  # section
  if child.element? && child.name =~ /^section$/
    hx_nodes << [ child.line, child.ancestors.size.to_s, child.name.to_s, "" ]
  end
  # titleとH1は内容も追記
  if child.element? && child.name =~ /^h[1-6]$|^title$/
    hx_nodes << [ child.line, child.ancestors.size.to_s, child.name.to_s, child.content.to_s.gsub(/\R/,"") ]
  end
end

# output headers
puts "line\tdepth\ttagname\tcontent"
# puts "確認用\tcontent"

hx_nodes.sort!.each do |node|
  puts "#{node[0]}\t#{node[1]}\t#{node[2]}\t#{node[3]}"
  # puts "#{node[2]}\t#{node[3]}"
end
