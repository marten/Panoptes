class SubjectSelector
  class MissingParameter < StandardError; end

  attr_reader :user, :params, :workflow

  def initialize(user, workflow, params, scope)
    @user, @workflow, @params, @scope = user, workflow, params, scope
  end

  def queued_subjects
    raise workflow_id_error unless workflow
    raise group_id_error if needs_set_id?

    queue = SubjectQueue.scoped_to_set(params[:subject_set_id])
            .find_by!(user: user.user, workflow: workflow)

    SubjectQueueWorker.perform_async(workflow.id, user.id) if queue.below_minimum?

    selected_subjects(queue.next_subjects(default_page_size))
  end

  def selected_subjects(sms_ids, selector_context={})
    subjects = @scope.joins(:set_member_subjects)
               .where(set_member_subjects: {id: sms_ids})
    [subjects, selector_context]
  end

  private

  def needs_set_id?
    workflow.grouped && !params.has_key(:group_id)
  end

  def workflow_id_error
    MissingParameter.new("workflow_id parameter missing")
  end

  def group_id_error
    MissingParameter.new("subject_set_id parameter missing for grouped workflow")
  end

  def default_page_size
    params[:page_size] ||= 10
  end
end
