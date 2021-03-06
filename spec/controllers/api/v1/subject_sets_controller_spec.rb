require 'spec_helper'

describe Api::V1::SubjectSetsController, type: :controller do
  let!(:subject_sets) { create_list :subject_set_with_subjects, 2 }
  let(:subject_set) { subject_sets.first }
  let(:project) { subject_set.project }
  let(:owner) { project.owner }
  let(:api_resource_name) { 'subject_sets' }

  let(:api_resource_attributes) { %w(id display_name set_member_subjects_count created_at updated_at metadata) }
  let(:api_resource_links) { %w(subject_sets.project subject_sets.workflows) }

  let(:scopes) { %w(public project) }
  let(:resource_class) { SubjectSet }
  let(:authorized_user) { owner }

  before(:each) do
    default_request scopes: scopes, user_id: owner.id
  end

  describe '#index' do
    let(:filterable_resources) { subject_sets }
    let(:expected_filtered_ids) { [ filterable_resources.first.id.to_s ] }
    let(:private_project) { create(:project, private: true) }
    let!(:private_resource) { create(:subject_set, project: private_project)  }
    let(:n_visible) { 2 }

    it_behaves_like 'is indexable'
    it_behaves_like 'has many filterable', :workflows
  end

  describe '#show' do
    let(:resource) { subject_set }

    it_behaves_like 'is showable'
  end

  describe '#update' do
    let(:subjects) { create_list(:subject, 4, project: project) }
    let(:workflow) { create(:workflow, project: project) }
    let(:resource) { create(:subject_set, project: project) }
    let(:resource_id) { :subject_set_id }
    let(:test_attr) { :display_name }
    let(:test_attr_value) { "A Better Name" }
    let(:test_relation) { :subjects }
    let(:test_relation_ids) { subjects.map { |s| s.id.to_s } }
    let(:update_params) do
      {
       subject_sets: {
                      display_name: "A Better Name",
                      expert_set: true,
                      links: {
                              workflows: [workflow.id.to_s],
                              subjects: subjects.map(&:id).map(&:to_s)
                             }

                     }
      }
    end

    it_behaves_like "is updatable"

    it_behaves_like "has updatable links"

    it_behaves_like "supports update_links"

    describe "update_links" do
      let(:sms_count) { resource.reload.set_member_subjects_count }
      let(:run_update_links) do
        default_request scopes: scopes, user_id: authorized_user.id
        params = {
          link_relation: test_relation.to_s,
          test_relation => test_relation_ids,
          resource_id => resource.id
        }
        post :update_links, params
      end

      it "should update the set_member_subject_count" do
        run_update_links
        expect(sms_count).to eq(test_relation_ids.count)
      end

      context "when the linking resources are not persisted" do

        it "should return a 422 with a missing subject" do
          allow(subjects.last).to receive(:id).and_return(0)
          run_update_links
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context "reload subject queue" do
      let(:workflows) { [create(:workflow, project: project)] }
      let(:resource) do
        ss = create(:subject_set,
               project: project,
               subjects: subjects)

        ss.workflows = workflows
        ss.save!
        ss
      end

      context "when the subject set has a workflow" do
        it 'should call the reload queue worker' do
          expect(ReloadQueueWorker).to receive(:perform_async).with(workflows.first.id)
          default_request scopes: scopes, user_id: authorized_user.id
          update_params[:subject_sets][:links].delete(:workflows)
          put :update, update_params.merge(id: resource.id)
        end
      end

      context "when the subject set has multiple workflows" do
        let(:workflows) { create_list(:workflow, 2, project: project) }
        it 'should call the reload queue worker' do
          expect(ReloadQueueWorker).to receive(:perform_async).twice
          default_request scopes: scopes, user_id: authorized_user.id
          update_params[:subject_sets][:links].delete(:workflows)
          put :update, update_params.merge(id: resource.id)
        end
      end

      context "when the subject set has no workflows" do
        let(:workflows) { [] }
        it 'should not call the reload queue worker' do
          expect(ReloadQueueWorker).to_not receive(:perform_async)
          default_request scopes: scopes, user_id: authorized_user.id
          update_params[:subject_sets][:links].delete(:workflows)
          put :update, update_params.merge(id: resource.id)
        end
      end

      context "when the subject set has multiple subjects" do
        it 'should call the reload queue worker' do
          expect(ReloadQueueWorker).to receive(:perform_async).with(workflows.first.id)
          default_request scopes: scopes, user_id: authorized_user.id
          update_params[:subject_sets][:links].delete(:workflows)
          put :update, update_params.merge(id: resource.id)
        end
      end

      context "when the subject set has no subjects" do
        let(:subjects) { [] }
        it 'should not call the reload queue worker' do
          expect(ReloadQueueWorker).to_not receive(:perform_async)
          default_request scopes: scopes, user_id: authorized_user.id
          update_params[:subject_sets].delete(:links)
          put :update, update_params.merge(id: resource.id)
        end
      end
    end
  end

  describe '#create' do
    let(:test_attr) { :display_name}
    let(:test_attr_value) { 'Test subject set' }
    let(:create_params) do
      {
       subject_sets: {
                      display_name: 'Test subject set',
                      expert_set: true,
                      metadata: {
                                 location: "Africa"
                                },
                      links: {
                              project: project.id
                             }
                     }
      }
    end

    context "create a new subject set" do
      it_behaves_like "is creatable"
    end

    context "create a subject set from a collection" do
      before(:each) do
        ps = create_params
        ps[:subject_sets][:links][:collection] = collection.id.to_s
        default_request user_id: authorized_user.id, scopes: scopes
        post :create, ps
      end

      context "when a user can access the collection" do
        let(:collection) { create(:collection_with_subjects) }
        it "should create a new subject set with the collection's subjects" do
          set = SubjectSet.find(created_instance_id(api_resource_name))
          expect(set.subjects).to match_array(collection.subjects)
        end
      end

      context "when the user cannot access the collection" do
        let(:collection) { create(:collection_with_subjects, private: true) }
        it "should return 404" do
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe '#destroy' do
    let(:resource) { subject_set }

    it_behaves_like "is destructable"
  end
end
