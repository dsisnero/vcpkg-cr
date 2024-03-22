require "./spec_helper"
require "../src/result"

alias StringResult = Ok(String) | Err(String)
alias NumberString = Ok(Int32) | Err(String)

class Example
  def identity(res : Result)
    res
  end

  def test_return_type(res)
    res = try!(identity(res))
    # Ok.new( (res + 5).to_s)
    Ok.new("hello")
  end
end

describe Result do
  describe "variants" do
    it "can be created with Ok" do
      result = Ok.new(42)
      result.should be_a(Result)
      result.should be_a(Ok(Int32))
      result.ok?.should be_true
      result.err?.should be_false
    end

    it "can be created with Err" do
      result = Err.new("Something went wrong")
      result.should be_a(Result)
      result.should be_a(Err(String))
      result.ok?.should be_false
      result.err?.should be_true
    end
  end

  describe "accessors" do
    it "returns the value for Ok variant" do
      result = Ok.new(42)
      result.unwrap.should eq(42)
    end

    it "raises error when accessing value on Err" do
      result = Err.new("Something went wrong")
      expect_raises(Exception, "Cannot unwrap an Err") do
        result.unwrap
      end
    end

    it "returns the error message for Err variant" do
      result = Err.new("Something went wrong")
      result.error.should eq("Something went wrong")
    end

    it "raises error when accessing error on Ok" do
      result = Ok.new(42)
      expect_raises(Exception, "Cannot unwrap_err on a Ok result") do
        result.unwrap_err
      end
    end
  end

  describe "map" do
    it "applies a function to a Ok value" do
      res = Ok.new(42)
      result = res.map { |x| x*2 }
      result.should eq Ok.new(84)
      result.unwrap.should eq(84)
    end

    it "returns the Err on a Err result" do
      res = Err.new("This is an Error")
      result = res.map { |x| x*2 }
      result.should eq Err.new("This is an Error")
      result.unwrap_err.should eq("This is an Error")
    end
  end

  describe "map_err" do
    it "returns the Ok when result is Ok" do
      res = Ok.new(42)
      result = res.map_err(&.size)
      result.should eq(Ok.new(42))
      result.unwrap.should eq(42)
    end

    it "applies a function to the error value" do
      res = Err.new("This is an error")
      result = res.map_err { |_| "This is a different error!" }
      result.should eq Err.new("This is a different error!")
      result.unwrap_err.should eq("This is a different error!")
    end
  end

  describe "try" do
    it "continues if given an Ok" do
      ex = Example.new
      result = ex.test_return_type(Ok.new(2))
      typeof(result).should eq Ok(Int32)
    end

    it "returns Err on err" do
      ex = Example.new
      result = ex.test_return_type(Err.new("oops"))
      typeof(result).should eq(Err(String))
    end
  end

  describe "unwrap" do
    it "returns the wrapped value if Ok" do
      res = Ok.new(42)
      res.unwrap.should eq 42
    end

    it "raises if it is an Err" do
      res = Err.new("oh no")
      expect_raises(Exception) { res.unwrap }
    end
  end

  describe "or" do
    it "returns the ok when result is ok" do
      res = Ok.new(42)
      result = res.or(Ok.new(43))
      result.should eq Ok.new(42)
    end
    it "returns alternate when receiver is an err" do
      res = Err.new("This is the error")
      typeof(res).should eq Err(String)
      result = res.or(Ok.new(43))
      result.ok?.should be_true
      typeof(result).should eq Ok(Int32)
      result.unwrap.should eq(43)
    end
  end
end
