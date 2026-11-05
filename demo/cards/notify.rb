def notify(user, ids)
  if user&.admin? && ids.select { |id| id.odd? }.any?
    'send'
  else
    'skip'
  end
end
