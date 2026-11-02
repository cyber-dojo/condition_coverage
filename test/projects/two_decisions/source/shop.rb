module Shop
  def self.fee(user, order)
    total = order.fetch(:total)
    total -= 5 if user.fetch(:member)
    total -= 10 if order.fetch(:total) > 100 && order.fetch(:paid)
    total
  end
end
