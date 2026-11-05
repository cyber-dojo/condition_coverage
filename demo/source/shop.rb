# A mock shop, written to show every shape of choice the report
# has to draw: conditions and paths, inside and outside methods.

# A condition at the top level, outside any method.
VERBOSE = ENV.fetch('VERBOSE', '') == '1' || ENV.key?('DEBUG')

# An if at the top level, outside any method.
if VERBOSE && $stdout.tty?
  warn 'shop: verbose'
end

module Shop
  # A condition at the module's top level, outside any method.
  LIMIT = ENV.key?('LIMIT') ? Integer(ENV.fetch('LIMIT')) : 10

  # Endless methods, each a condition and nothing else.
  def self.member?(user) = user[:member] && !user[:banned]
  def self.vip?(user) = member?(user) && (user[:spend] > 1000 || user[:invited])

  # A long method, its paths and conditions tightly mixed.
  def self.price(user, order)
    items = order[:items]
    fail ArgumentError, 'empty order' if items.empty?

    total = items.sum { |item| item[:price] }

    if member?(user) && total > 50
      total -= 5
    end

    if vip?(user)
      total -= 10
    elsif user[:coupon] || order[:coupon]
      total -= 2
    end

    shipping = total > 100 || order[:pickup] ? 0 : 7

    unless order[:express]
      shipping /= 2
    end

    if order[:gift] &&
       (order[:wrap] || user[:member])
      total += 3
    else
      total += 0 if order[:gift]
    end

    return total if order[:pickup]

    total + shipping
  end

  # A method that defines a method inside it.
  def self.install_discounts(rates)
    if rates.empty?
      return
    end

    def self.discount(total, rate)
      off = 0
      if rate.positive? && total.positive?
        off = total * rate
      end
      if off > 20
        off = 20
      end
      off
    end

    if rates.size > 1 || rates.first > 0.5
      @tiered = true
    end
  end

  # Choices inside a block, which runs once for each item.
  def self.labels(items)
    items.map do |item|
      if item[:sale] && item[:price] < 10
        'bargain'
      elsif item[:sale]
        'sale'
      else
        'full price'
      end
    end
  end

  # A short method: one if, so its paths are its branches.
  def self.greeting(user)
    if user[:name] && !user[:name].empty?
      "Hello #{user[:name]}"
    else
      'Hello'
    end
  end
end
