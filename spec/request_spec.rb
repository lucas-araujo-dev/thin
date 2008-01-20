require File.dirname(__FILE__) + '/spec_helper'
require 'digest/sha1'

describe Request do
  it 'should include basic headers' do
    request = R("GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
    request.env['SERVER_PROTOCOL'].should == 'HTTP/1.1'
    request.env['REQUEST_PATH'].should == '/'
    request.env['HTTP_VERSION'].should == 'HTTP/1.1'
    request.env['REQUEST_URI'].should == '/'
    request.env['GATEWAY_INTERFACE'].should == 'CGI/1.2'
    request.env['REQUEST_METHOD'].should == 'GET'
    request.env["rack.url_scheme"].should == 'http'
    request.env['FRAGMENT'].to_s.should be_empty
    request.env['QUERY_STRING'].to_s.should be_empty
    
    request.should validate_with_lint
  end
  
  it 'should not prepend HTTP_ to Content-Type and Content-Length' do
    request = R("POST / HTTP/1.1\r\nHost: localhost\r\nContent-Type: text/html\r\nContent-Length: 2\r\n\r\naa")
    request.env.keys.should_not include('HTTP_CONTENT_TYPE', 'HTTP_CONTENT_LENGTH')
    request.env.keys.should include('CONTENT_TYPE', 'CONTENT_LENGTH')
    
    request.should validate_with_lint
  end
  
  it 'should raise error on invalid request line' do
    proc { R("GET / SsUTF/1.1") }.should raise_error(InvalidRequest)
    proc { R("GET / HTTP/1.1yousmelllikecheeze") }.should raise_error(InvalidRequest)
  end
  
  it 'should support fragment in uri' do
    request = R("GET /forums/1/topics/2375?page=1#posts-17408 HTTP/1.1\r\nHost: localhost\r\n\r\n")

    request.env['REQUEST_URI'].should == '/forums/1/topics/2375?page=1'
    request.env['PATH_INFO'].should == '/forums/1/topics/2375'
    request.env['QUERY_STRING'].should == 'page=1'
    request.env['FRAGMENT'].should == 'posts-17408'
    
    request.should validate_with_lint
  end
  
  it 'should parse path with query string' do
    request = R("GET /index.html?234235 HTTP/1.1\r\nHost: localhost\r\n\r\n")
    request.env['REQUEST_PATH'].should == '/index.html'
    request.env['QUERY_STRING'].should == '234235'
    request.env['FRAGMENT'].should be_nil
    
    request.should validate_with_lint
  end
  
  it 'should raise error on large header names' do
    proc { R("GET /#{rand_data(10,120)} HTTP/1.1\r\nX-#{rand_data(1024, 1024+(1024))}: Test\r\n\r\n") }.
      should raise_error(InvalidRequest)
  end

  it 'should raise error on large mangled field values' do
    proc { R("GET /#{rand_data(10,120)} HTTP/1.1\r\nX-Test: #{rand_data(1024, 100*1024+(1024), false)}\r\n\r\n") }.
      should raise_error(InvalidRequest)
  end
  
  it 'should raise error on big fat ugly headers' do
    get = "GET /#{rand_data(10,120)} HTTP/1.1\r\n"
    get << "X-Test: test\r\n" * (80 * 1024)
    proc { R(get) }.should raise_error(InvalidRequest)
  end

  it 'should raise error on random garbage' do
    proc { R("GET #{rand_data(1024, 1024+(1024), false)} #{rand_data(1024, 1024+(1024), false)}\r\n\r\n") }.
      should raise_error(InvalidRequest)
  end
  
  it 'should parse headers from GET request' do
    request = R(<<-EOS, true)
GET / HTTP/1.1
Host: localhost:3000
User-Agent: Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en-US; rv:1.8.1.9) Gecko/20071025 Firefox/2.0.0.9
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5
Accept-Language: en-us,en;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Cookie: mium=7
Keep-Alive: 300
Connection: keep-alive

EOS
    request.env['HTTP_HOST'].should == 'localhost:3000'
    request.env['SERVER_NAME'].should == 'localhost'
    request.env['SERVER_PORT'].should == '3000'
    request.env['HTTP_COOKIE'].should == 'mium=7'
    
    request.should validate_with_lint
  end
  
  it 'should parse POST request with data' do
    request = R(<<-EOS.chomp, true)
POST /postit HTTP/1.1
Host: localhost:3000
User-Agent: Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en-US; rv:1.8.1.9) Gecko/20071025 Firefox/2.0.0.9
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5
Accept-Language: en-us,en;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Keep-Alive: 300
Connection: keep-alive
Content-Type: text/html
Content-Length: 37

name=marc&email=macournoyer@gmail.com
EOS

    request.env['REQUEST_METHOD'].should == 'POST'
    request.env['REQUEST_URI'].should == '/postit'
    request.env['CONTENT_TYPE'].should == 'text/html'
    request.env['CONTENT_LENGTH'].should == '37'
    request.env['HTTP_ACCEPT'].should == 'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5'
    request.env['HTTP_ACCEPT_LANGUAGE'].should == 'en-us,en;q=0.5'

    request.body.rewind
    request.body.read.should == 'name=marc&email=macournoyer@gmail.com'
    request.body.class.should == StringIO
    
    request.should validate_with_lint
  end
  
  it 'should not fuck up on stupid fucked IE6 headers' do
    body = <<-EOS
POST /codes/58-tracking-file-downloads-automatically-in-google-analytics-with-prototype/refactors HTTP/1.0
X-Real-IP: 62.24.71.95
X-Forwarded-For: 62.24.71.95
Host: refactormycode.com
Connection: close
TE: deflate,gzip;q=0.3
Accept: */*
Range: bytes=0-499999
Referer: http://refactormycode.com/codes/58-tracking-file-downloads-automatically-in-google-analytics-with-prototype
User-Agent: Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)
Content-Length: 1
Content-Type: application/x-www-form-urlencoded
Cookie: _refactormycode_session_id=a1b2n3jk4k5; flash=%7B%7D
Cookie2: $Version="1"

a
EOS
    request = R(body, true)
    request.env['HTTP_COOKIE2'].should == '$Version="1"'
    
    request.should validate_with_lint
  end
  
  it 'shoud accept long query string' do
    body = <<-EOS
GET /session?open_id_complete=1&nonce=ytPOcwni&nonce=ytPOcwni&openid.assoc_handle=%7BHMAC-SHA1%7D%7B473e38fe%7D%7BJTjJxA%3D%3D%7D&openid.identity=http%3A%2F%2Fmacournoyer.myopenid.com%2F&openid.mode=id_res&openid.op_endpoint=http%3A%2F%2Fwww.myopenid.com%2Fserver&openid.response_nonce=2007-11-29T01%3A19%3A35ZGA5FUU&openid.return_to=http%3A%2F%2Flocalhost%3A3000%2Fsession%3Fopen_id_complete%3D1%26nonce%3DytPOcwni%26nonce%3DytPOcwni&openid.sig=lPIRgwpfR6JAdGGnb0ZjcY%2FWjr8%3D&openid.signed=assoc_handle%2Cidentity%2Cmode%2Cop_endpoint%2Cresponse_nonce%2Creturn_to%2Csigned%2Csreg.email%2Csreg.nickname&openid.sreg.email=macournoyer%40yahoo.ca&openid.sreg.nickname=macournoyer HTTP/1.1
Host: localhost:3000

EOS
    request = R(body, true)
    
    request.env['QUERY_STRING'].should == 'open_id_complete=1&nonce=ytPOcwni&nonce=ytPOcwni&openid.assoc_handle=%7BHMAC-SHA1%7D%7B473e38fe%7D%7BJTjJxA%3D%3D%7D&openid.identity=http%3A%2F%2Fmacournoyer.myopenid.com%2F&openid.mode=id_res&openid.op_endpoint=http%3A%2F%2Fwww.myopenid.com%2Fserver&openid.response_nonce=2007-11-29T01%3A19%3A35ZGA5FUU&openid.return_to=http%3A%2F%2Flocalhost%3A3000%2Fsession%3Fopen_id_complete%3D1%26nonce%3DytPOcwni%26nonce%3DytPOcwni&openid.sig=lPIRgwpfR6JAdGGnb0ZjcY%2FWjr8%3D&openid.signed=assoc_handle%2Cidentity%2Cmode%2Cop_endpoint%2Cresponse_nonce%2Creturn_to%2Csigned%2Csreg.email%2Csreg.nickname&openid.sreg.email=macournoyer%40yahoo.ca&openid.sreg.nickname=macournoyer'
    
    request.should validate_with_lint
  end
  
  it 'should parse even with stupid Content-Length' do
    body = <<-EOS.chomp
POST / HTTP/1.1
Host: localhost:3000
Content-Length: 300

aye
EOS
    request = R(body, true)
    
    request.body.rewind
    request.body.read.should == 'aye'
  end
  
  it 'should parse in chunks' do
    request = Request.new
    request.parse("POST / HTTP/1.1\r\n").should be_false
    request.parse("Host: localhost\r\n").should be_false
    request.parse("Content-Length: 9\r\n").should be_false
    request.parse("\r\nvery ").should be_false
    request.parse("cool").should be_true
    
    request.env['CONTENT_LENGTH'].should == '9'
    request.body.read.should == 'very cool'
    request.should validate_with_lint
  end
  
  it "should move body to tempfile when too big" do
    body = 'X' * (Request::MAX_BODY + 1)
    
    request = R(<<-EOS.chomp, true)
POST /postit HTTP/1.1
Host: localhost:3000
Content-Type: text/html
Content-Length: #{body.size}

#{body}
EOS
    
    request.body.class.should == Tempfile
  end
  
  it "should raise error when header is too big" do
    big_headers = "X-Test: X\r\n" * (1024 * (80 + 32))
    proc { R("GET / HTTP/1.1\r\n#{big_headers}\r\n") }.should raise_error(InvalidRequest)
  end
  
  it "should be faster then #{max_parsing_time = 0.2} ms" do
    body = <<-EOS.chomp
POST /postit HTTP/1.1
Host: localhost:3000
User-Agent: Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en-US; rv:1.8.1.9) Gecko/20071025 Firefox/2.0.0.9
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5
Accept-Language: en-us,en;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Keep-Alive: 300
Connection: keep-alive
Content-Type: text/html
Content-Length: 37

hi=there&name=marc&email=macournoyer@gmail.com
EOS
    
    proc { R(body, true) }.should be_faster_then(max_parsing_time)
  end
  
  it 'should be comparable to Mongrel parser' do
    require 'http11'
  
    body = <<-EOS.chomp.gsub("\n", "\r\n")
POST /postit HTTP/1.1
Host: localhost:3000
User-Agent: Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en-US; rv:1.8.1.9) Gecko/20071025 Firefox/2.0.0.9
Accept: text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5
Accept-Language: en-us,en;q=0.5
Accept-Encoding: gzip,deflate
Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7
Keep-Alive: 300
Connection: keep-alive
Content-Type: text/html
Content-Length: 37

hi=there&name=marc&email=macournoyer@gmail.com
EOS
  
    tests = 10_000
    puts
    Benchmark.bmbm(10) do |results|
      results.report("mongrel:") { tests.times { Mongrel::HttpParser.new.execute({}, body.dup, 0) } }
      results.report("thin:") { tests.times { Thin::HttpParser.new.execute({'rack.input' => StringIO.new}, body.dup, 0) } }
    end
  end if ENV['BM']
  
  private
    def rand_data(min, max, readable=true)
      count = min + ((rand(max)+1) *10).to_i
      res = count.to_s + "/"

      if readable
        res << Digest::SHA1.hexdigest(rand(count * 100).to_s) * (count / 40)
      else
        res << Digest::SHA1.digest(rand(count * 100).to_s) * (count / 20)
      end

      return res
    end
    
    def R(raw, convert_line_feed=false)
      raw.gsub!("\n", "\r\n") if convert_line_feed
      request = Thin::Request.new
      request.parse(raw)
      request
    end
end