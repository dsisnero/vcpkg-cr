module Result
end

record Ok(T), value : T do
  include Result

  def ok?
    true
  end

  def err?
    false
  end

  def unwrap
    @value
  end

  def unwrap_err
    raise "Cannot unwrap_err on a Ok result"
  end

  def or(res)
    self
  end

  def map(&block : T -> U) forall U
    Ok.new(block.call @value)
  end

  def map_err(&)
    self
  end
end

record Err(E), error : E do
  include Result

  def unwrap
    raise "Cannot unwrap an Err"
  end

  def unwrap_err
    @error
  end

  def ok?
    false
  end

  def err?
    true
  end

  def map(&)
    self
  end

  def map_err(&)
    Err.new(yield @error)
  end

  def or(res : Result)
    res
  end
end

macro try!(result)

  %res = {{result}}
  if %res.err?
    return %res
  else
    %res.unwrap
  end
end
