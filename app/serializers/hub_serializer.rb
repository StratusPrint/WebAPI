class HubSerializer < ActiveModel::Serializer
  attributes :id, :friendly_id, :desc, :location, :ip, :hostname, :status, :api_token
end
