class UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :image, :email, :admin, :last_sign_in_ip, :current_sign_in_ip, :last_sign_in_at, :current_sign_in_at, :created_at, :default_hub_id
end
