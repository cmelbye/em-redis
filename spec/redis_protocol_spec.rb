require File.expand_path(File.dirname(__FILE__) + "/test_helper.rb")

EM.describe EM::Protocols::Redis do

  before do
    @c = TestConnection.new
  end

  # Inline request protocol
  should 'send inline commands correctly' do
    @c.inline_command("GET", 'a')
    @c.sent_data.should == "GET a\r\n"
    done
  end
  
  should "space-separate multiple inline arguments" do
    @c.inline_command("GET", 'a', 'b', 'c')
    @c.sent_data.should == "GET a b c\r\n"
    done
  end

  # Multiline request protocol
  should "send multiline commands correctly" do
    @c.multiline_command("SET", "foo", "abc")
    @c.sent_data.should == "SET foo 3\r\nabc\r\n"
    done
  end

  # Specific calls
  #
  # SORT
  should "send sort command" do
    @c.sort "foo"
    @c.sent_data.should == "SORT foo\r\n"
    done
  end

  should "send sort command with all optional parameters" do
    @c.sort "foo", "foo_sort_*", 0, 10, "data_*", true, true
    @c.sent_data.should == "SORT foo BY foo_sort_* LIMIT 0 10 GET data_* DESC ALPHA\r\n"
    done
  end

  should "parse keys response into an array" do
    @c.keys "*" do |resp|
      resp.should == ["a","b","c"]
      done
    end
    @c.receive_data "$5\r\na b c\r\n"
  end


  # Inline response
  should "parse an inline response" do
    @c.inline_command("PING") do |resp|
      resp.should == "OK"
      done
    end
    @c.receive_data "+OK\r\n"
  end

  should "parse an inline integer response" do
    @c.inline_command("EXISTS") do |resp|
      resp.should == 0
      done
    end
    @c.receive_data ":0\r\n"
  end

  should "parse an inline error response" do
    lambda do
      @c.inline_command("BLARG")
      @c.receive_data "-FAIL\r\n"
    end.should.raise(EM::P::Redis::RedisError)
    done
  end

  should "trigger a given error callback for inline error response instead of raising an error" do
    lambda do
      @c.inline_command("BLARG")
      @c.on_error {|code| code.should == "FAIL"; done }
      @c.receive_data "-FAIL\r\n"
    end.should.not.raise(EM::P::Redis::RedisError)
    done
  end

  # Bulk response
  should "parse a bulk response" do
    @c.inline_command("GET", "foo") do |resp|
      resp.should == "bar"
      done
    end
    @c.receive_data "$3\r\n"
    @c.receive_data "bar\r\n"
  end

  should "distinguish nil in a bulk response" do
    @c.inline_command("GET", "bar") do |resp|
      resp.should == nil
    end
    @c.receive_data "$-1\r\n"
  end
  
  # Multi-bulk response
  
  should "parse a multi-bulk response" do
    @c.inline_command "RANGE", 0, 10 do |resp|
      resp.should == ["a", "b", "foo"]
      done
    end
    @c.receive_data "*3\r\n"
    @c.receive_data "$1\r\na\r\n"
    @c.receive_data "$1\r\nb\r\n"
    @c.receive_data "$3\r\nfoo\r\n"
  end

  should "distinguish nil in a multi-bulk response" do
    @c.inline_command "RANGE", 0, 10 do |resp|
      resp.should == ["a", nil, "foo"]
      done
    end
    @c.receive_data "*3\r\n"
    @c.receive_data "$1\r\na\r\n"
    @c.receive_data "$-1\r\n"
    @c.receive_data "$3\r\nfoo\r\n"
  end
end
