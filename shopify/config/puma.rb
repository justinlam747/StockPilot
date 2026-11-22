bind "tcp://127.0.0.1:#{ENV.fetch('PORT', 3001)}"
environment ENV.fetch('RAILS_ENV', 'development')
