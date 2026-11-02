# The fee for an order: 5 off for a member who has paid, and
# 10 off a big order.
def fee(user, order)
  total = 100
  if user.member? && order.paid?
    total -= 5
  end
  if order.big?
    total -= 10
  end
  total
end
