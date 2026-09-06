Badger::Engine.routes.draw do
  resources :badges do
    # Dressing a badge. `new` is the palette picker, `create` takes the
    # snapshot, `update` binds one slot to a rule, `drift` asks Pandatone
    # whether the palette has moved.
    resources :colorways, only: %i[ new create update destroy ], module: :badges do
      patch :drift, on: :member
    end
  end

  # The API is versioned from the first commit: other tools depend on this
  # contract, and the way to change it is to add v2, not to edit v1.
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      get "openapi", to: "openapi#show", as: :openapi
      resources :badges, only: %i[ index show ], param: :key
      resources :colorways, only: %i[ index show ]
    end
  end

  root "badges#index"
end
