module Api

  class EventsController < ApplicationController

    KNOWN_EVENTS = %w( activity workflow_activity )

    def self.resource_name
      "event"
    end

    @actions = [:create]

    include JsonApiController::JsonSchemaValidator

    before_action :require_basic_authentication

    def create
      respond_to do |format|
        format.json { process_incoming_event }
      end
    end

    private

    def require_basic_authentication
      authenticate_or_request_with_http_basic do |username, password|
        Panoptes::EventsApi.username == username &&
          Panoptes::EventsApi.password == password
      end
    end

    def process_incoming_event
      response_status = :unprocessable_entity
      if event_params_sanity_check
        upp = user_project_preference
        upp.activity_count = create_params[:count]
        response_status = :ok if upp.save
      end
      render status: response_status, nothing: true
    end

    def event_params_sanity_check
      required_params && known_event?
    end

    def required_params
      params_to_check = [ create_params[:project_id], create_params[:zooniverse_user_id] ]
      params_to_check.all? { |param| !param.blank? }
    rescue JsonSchema::ValidationError
      return false
    end

    def known_event?
      unless known_event = create_params[:kind] && KNOWN_EVENTS.include?(create_params[:kind])
        notify_honeybadger_of_unknown_event
      end
      known_event
    end

    def notify_honeybadger_of_unknown_event
      Honeybadger.notify(
        error_class:   "Legacy API Event",
        error_message: "Unknown Legacy API Event Message Received",
        parameters:    params
      )
    end

    def user_project_preference
      UserProjectPreference.find_or_initialize_by(project_id: create_params[:project_id],
                                                  user_id: create_params[:zooniverse_user_id])
    end

    def resource_sym
      self.class.resource_name.pluralize.to_sym
    end
  end
end
