Rails.application.routes.draw do
  mount Badger::Engine => "/badger"

  # Somewhere public to land on, so a browser test can plant its cookie
  # before it reaches the engine.
  root "home#show"
end
