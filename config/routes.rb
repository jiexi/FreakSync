CoffeePractice::Application.routes.draw do
  root "homepage#index"
  get 'code', to: 'homepage#code'
  get 'demo', to: 'webaudio#recorder'
end
