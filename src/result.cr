module Result
  def self.new(value : T? = nil, error : E? = nil) : Ok(T) | Err(E) | Nil
    if value && !error
      self.ok(value)
    elsif error && !value
      self.err(error)
    elsif value && error
      raise "argument must be value | error, not both"
    else
      raise "must supply one of value | error"
    end
  end

  def self.ok(value : T) : Ok(T)
    Ok.new(value)
  end

  def self.err(error : E) : Err(E)
    Err.new(error)
  end
end

struct Ok(T)
  include Result

  getter value : T

  def initialize(@value : T)
  end

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

  def map(&)
    Ok.new(yield @value)
  end

  def map_err(&)
    self
  end
end

struct Err(E)
  include Result

  getter error : E

  def initialize(@error)
  end

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
  {% debug %}
end
