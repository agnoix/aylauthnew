Rails.application.routes.draw do
  scope :module => "Aylauth" do
    # TODO: Brainstorm on allowing dots in IDs - SVC-466
    # Affects logout and update_role API due to dots in OAuth token
    resources :sessions, :only => [:new, :create, :destroy], :id => /.*/ do
      get :provider_auth, on: :collection
      get :post_process_provider_auth, on: :collection
      post :accept_terms, on: :collection
      put  :update_role, on: :member
      get :desk_dot_com_sso, on: :collection
    end
    resources :registrations, :only => [:new, :create, :update, :show, :destroy] do
      get :edit, :on => :collection
    end
    resource :password, :only => [:new, :create, :edit, :update]
    resource :confirmation, :only => [:new, :create]
    resources :notifications, :only => [] do
      post :logout, on:  :collection
      post :refresh_user, on: :collection
      post :refresh_contact, on: :collection
    end

  end
end
