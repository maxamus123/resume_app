Rails.application.routes.draw do
  # Chat feature routes
  get 'chat', to: 'chat#index'
  post 'chat/message', to: 'chat#message'
  get 'chat/stream_message', to: 'chat#stream_message'
  
  # Resume PDF download - moved above other routes to ensure correct routing
  get 'resume.pdf', to: 'home#resume_pdf', as: 'resume_pdf'
  
  # Set interactive view as the root
  root 'home#interactive'
  
  # Original resume view
  get 'resume', to: 'home#index'
  
  # Individual section pages
  resources :experiences, only: [:index]
  resources :educations, only: [:index]
  resources :skills, only: [:index]
  resources :languages, only: [:index]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
