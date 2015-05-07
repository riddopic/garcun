
# God speaks in Ruby, not Python!! MsgFromGod is an implementation of a
# Higher-Order-Message. Essentally, a MsgFromGod can vary its behavior
# accorrding to the operation applied to it.
#
# @example
#   g = MsgFromGod.new { |op, x| x.send(op, x) }
#   (g + 1)  # => 2
#   (g + 2)  # => 4
#   (g + 3)  # => 6
#   (g * 1)  # => 1
#   (g * 2)  # => 4
#   (g * 3)  # => 9
#
class MsgFromGod

  # MsgFromGod can be somewhat inefficient if a new MsgFromGod is frequently
  # recreated for the same use. So this cache can be used to speed things up.
  #
  # The key will always be an array, wich makes it easier to cache MsgFromGod
  # for multiple factors.
  #
  def self.cache(*key, &function)
    @cache ||= {}
    if function
      @cache[key] = new(&function)
    else
      @cache[key]
    end
  end

  EXCEPTIONS = [:binding, :inspect, :object_id]
  if defined?(::BasicObject)
    EXCEPTIONS.concat(::BasicObject.instance_methods)
    EXCEPTIONS.uniq!
    EXCEPTIONS.map! { |m| m.to_sym }
  end

  alias :__class__ :class

  # Privatize all methods except vital methods and #binding.
  instance_methods(true).each do |m|
    next if m.to_s =~ /^__/
    next if EXCEPTIONS.include?(m.to_sym)
    undef_method(m)
  end

  def initialize(&function)
    @function = function
  end

  def to_proc
    @function
  end

  private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

  # Any action against the MsgFromGod is processesd by the function.
  def method_missing(op, *args, &blk)
    @function.call(op, *args, &blk)
  end
end
