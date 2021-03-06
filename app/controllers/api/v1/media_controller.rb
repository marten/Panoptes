class Api::V1::MediaController < Api::ApiController
  doorkeeper_for :update, :create, :destroy, scopes: [:medium]
  resource_actions :default

  schema_type :json_schema

  def schema_class(action)
    "medium_#{ action }_schema".camelize.constantize
  end

  def index
    unless media.blank?
      @controlled_resources = Medium.where(id: media.try(:id) || media)
      super
    else
      raise Api::NoMediaError.new(media_name, resource_name, resource_ids)
    end
  end

  def show
    error_unless_exists
    set_controlled_resources
    super
  end

  def destroy
    error_unless_exists
    set_controlled_resources
    super
  end

  def create
    @controlled_resources = api_user.do(:update)
      .to(resource_class, scope_context)
      .with_ids(resource_ids)
      .scope

    check_controller_resources

    assoc = resource_class.reflect_on_association(media_name)
    created = case assoc.macro
              when :has_one
                if old_resource = controlled_resource.send(media_name)
                  old_resource.destroy
                end
                controlled_resource.send("create_#{media_name}!", create_params)
              when :has_many
                controlled_resource.send(media_name).create!(create_params)
              end

    created_resource_response(created)
  end

  def set_controlled_resources
    @controlled_resources = media.where(id: params[:id])
  end

  def media
    @media ||= controlled_resource.send(media_name)
  end

  def error_unless_exists
    unless media.exists?(params[:id])
      raise Api::NoMediaError.new(media_name, resource_name, resource_ids, params[:id])
    end
  end

  def link_header(resource)
    "#{request.protocol}#{request.host_with_port}/api#{resource.location}"
  end

  def context
    case action_name
    when "update", "create"
      { url_format: :put }
    else
      { url_format: :get }
    end
  end

  def serializer
    MediumSerializer
  end

  def resource_sym
    :media
  end

  def resource_name
    @resource_name ||= params.keys.find{ |key| key.to_s.match(/_id/) }[0..-4]
  end

  def media_name
    params[:media_name]
  end

  def controlled_scope
    case media_name
    when "classifications_export"
      :update
    else
      action_name.to_sym
    end
  end

  def precondition_fails?
    query = Medium.where(id: params[:id])
    !(gen_etag(query) == precondition)
  end

  private
  def resource_scope(resources)
    return resources if resources.is_a?(ActiveRecord::Relation)
    Medium.where(id: resources.try(:id) || resources.map(&:id))
  end
end
