require 'spec_helper'

RSpec.describe SubjectQueue, :type => :model do
  let(:locked_factory) { :subject_queue }
  let(:locked_update) { {set_member_subject_ids: [1, 2, 3, 4]} }

  it_behaves_like "optimistically locked"

  it 'should have a valid factory' do
    expect(build(:subject_queue)).to be_valid
  end

  it 'should not be valid with out a workflow' do
    expect(build(:subject_queue, workflow: nil)).to_not be_valid
  end

  it 'should not be valid unless its is unique for the set, workflow, and user' do
    q = create(:subject_queue)
    expect(build(:subject_queue, subject_set: q.subject_set, workflow: q.workflow, user: q.user)).to_not be_valid
  end

  it 'should be valid if the subject set is different but the workflow and user are the same' do
    q = create(:subject_queue)
    expect(build(:subject_queue, workflow: q.workflow, user: q.user)).to be_valid
  end

  describe "::below_minimum" do
    let(:smses) { create_list(:set_member_subject, 21) }
    let!(:above_minimum) { create(:subject_queue, set_member_subjects: smses) }
    let!(:below_minimum) { create(:subject_queue, set_member_subjects: smses[0..5]) }
    it 'should return all the queues with less than the minimum number of subjects' do
      expect(SubjectQueue.below_minimum).to include(below_minimum)
    end

    it 'should not return queues with more than minimum' do
      expect(SubjectQueue.below_minimum).to_not include(above_minimum)
    end
  end

  describe "::create_for_user" do
    let(:workflow) {create(:workflow)}
    let(:user) { create(:user) }

    context "when no logged out queue" do

      it 'should attempt to build a logged out queue' do
        expect(SubjectQueueWorker).to receive(:perform_async).with(workflow.id, nil)
        SubjectQueue.create_for_user(workflow, user)
      end

      it 'should return nil' do
        expect(SubjectQueue.create_for_user(workflow, user)).to be_nil
      end
    end

    context "queue saves" do
      it 'should return the new queue' do
        create(:subject_queue, workflow: workflow, user: nil, subject_set: nil)
        expect(SubjectQueue.create_for_user(workflow, user)).to be_a(SubjectQueue)
      end
    end
  end

  describe "::reload" do
    let(:sms) { create(:set_member_subject) }
    let(:smses) { create_list(:set_member_subject, 3).map(&:id) }
    let(:workflow) { create(:workflow) }

    context "when passed a subject set" do
      let(:subject_set) { create(:subject_set) }
      let(:not_updated_set) { create(:subject_set) }

      context "when the queue exists" do

        let!(:queue) do
          create(:subject_queue,
                 user: nil,
                 workflow: workflow,
                 set_member_subject_ids: [sms.id],
                 subject_set: subject_set)
        end

        let!(:not_updated_queue) do
          create(:subject_queue,
                 user: nil,
                 workflow: workflow,
                 set_member_subject_ids: [sms.id],
                 subject_set: not_updated_set)
        end

        before(:each) do
          SubjectQueue.reload(workflow, smses, set: subject_set.id)
          queue.reload
          not_updated_queue.reload
        end

        it 'should completely replace the queue for the given set' do
          expect(queue.set_member_subject_ids).to eq(smses)
        end

        it 'should not update the set without the name' do
          expect(not_updated_queue.set_member_subject_ids).to_not eq(smses)
        end
      end

      context "when no queue exists" do
        before(:each) do
          SubjectQueue.reload(workflow, smses, set: subject_set.id)
        end

        subject { SubjectQueue.find_by(workflow: workflow, subject_set: subject_set) }

        it 'should create a new queue with the given workflow' do
          expect(subject.workflow).to eq(workflow)
        end

        it 'should create a new queue with the given subject set' do
          expect(subject.subject_set).to eq(subject_set)
        end

         it 'should queue subject' do
          expect(subject.set_member_subject_ids).to eq(smses)
        end
      end
    end

    context "when not passed a subject set" do
      context "when a queue exists" do
        let!(:queue) do
          create(:subject_queue,
                 user: nil,
                 workflow: workflow,
                 set_member_subject_ids: [sms.id])
        end

        it 'should reload the workflow queue' do
          SubjectQueue.reload(workflow, smses)
          queue.reload
          expect(queue.set_member_subject_ids).to eq(smses)
        end
      end

      context "when a queue does not exist" do
        before(:each) do
          SubjectQueue.reload(workflow, smses)
        end

        subject { SubjectQueue.find_by(workflow: workflow) }

        it 'should create a new queue with the given workflow' do
          expect(subject.workflow).to eq(workflow)
        end

        it 'should queue subject' do
          expect(subject.set_member_subject_ids).to eq(smses)
        end
      end
    end
  end

  describe "::dequeue_for_all" do
    let(:sms) { create(:set_member_subject) }
    let(:workflow) { create(:workflow) }
    let(:queue) { create_list(:subject_queue, 2, workflow: workflow, set_member_subject_ids: [sms.id]) }

    it "should remove the subject for all queues of the workflow" do
      SubjectQueue.dequeue_for_all(workflow.id, sms.id)
      expect(SubjectQueue.all.map(&:set_member_subject_ids)).to all( be_empty )
    end
  end

  describe "::enqueue_for_all" do
    let(:sms) { create(:set_member_subject) }
    let(:workflow) { create(:workflow) }
    let(:queue) { create_list(:subject_queue, 2, workflow: workflow) }

    it "should add the subject for all queues of the workflow" do
      SubjectQueue.enqueue_for_all(workflow.id, sms.id)
      expect(SubjectQueue.all.map(&:set_member_subject_ids)).to all( include(sms.id) )
    end
  end

  describe "::enqueue" do
    let(:workflow) { create(:workflow) }
    let(:subject_set) { create(:subject_set, workflows: [workflow]) }
    let(:sms) { create(:set_member_subject, subject_set: subject_set) }

    context "with a user" do
      let(:user) { create(:user) }
      context "nothing for user" do

        shared_examples "queues something" do
          it 'should create a new user_enqueue_subject' do
            expect do
              SubjectQueue.enqueue(workflow,
                                   ids,
                                   user: user)
            end.to change{ SubjectQueue.count }.from(0).to(1)
          end

          it 'should add subjects' do
            SubjectQueue.enqueue(workflow, ids, user: user)
            queue = SubjectQueue.find_by(workflow: workflow, user: user)
            expect(queue.set_member_subject_ids).to include(*ids)
          end
        end

        shared_examples "does not queue anything" do |arg|
          it 'should not raise an error' do
            expect {
              SubjectQueue.enqueue(workflow, [], user: user)
            }.to_not raise_error
          end

          it 'not attempt to find or create a queue' do
            expect(SubjectQueue).to_not receive(:find_or_create_by!)
            SubjectQueue.enqueue(workflow, [], user: user)
          end

          it 'should not call #enqueue_update' do
            expect_any_instance_of(SubjectQueue).to_not receive(:enqueue_update)
            SubjectQueue.enqueue(workflow, [], user: user)
          end

          it 'should return nil' do
            expect(SubjectQueue.enqueue(workflow, [], user: user)).to be_nil
          end
        end

        context "passing one sms_id" do
          let(:ids) { sms.id }

          it_behaves_like "queues something"
        end

        context "passing a set of sms_ids" do
          let(:ids) { create_list(:set_member_subject, 5).map(&:id) }

          it_behaves_like "queues something"
        end

        context "passing an empty set of sms_ids" do
          it_behaves_like "does not queue anything", []
        end

        context "passing a set with one nil value" do
          it_behaves_like "does not queue anything", [nil]
        end
      end

      context "list exists for user" do
        let!(:smses) { create_list(:set_member_subject, 3, subject_set: sms.subject_set) }
        let!(:ues) do
          create(:subject_queue,
                 set_member_subject_ids: smses.map(&:id),
                 user: user,
                 workflow: workflow)
        end
        let!(:sms_ids) { ues.set_member_subject_ids - [ sms.id ] }

        it 'should call add_subject_id on the existing subject queue' do
          SubjectQueue.enqueue(workflow, sms.id, user: user)
          expect(ues.reload.set_member_subject_ids).to include(sms.id)
        end

        it 'should not have a duplicate in the set' do
          SubjectQueue.enqueue(workflow, sms.id, user: user)
          sms_ids = ues.reload.set_member_subject_ids
          expect(sms_ids.size).to eq(sms_ids.uniq.size)
        end


        context "when a queue's existing SMSes are deleted", sidekiq: :inline do
          before(:each) do
            sms_ids.each do |sms_id|
              QueueRemovalWorker.perform_async(sms_id, workflow.id)
            end
            SubjectQueue.enqueue(workflow, sms.id, user: user)
          end

          it "should only have the enqueued subject id in the queue" do
            expect(ues.reload.set_member_subject_ids).to match_array([ sms.id ])
          end
        end
      end
    end
  end

  describe "::dequeue" do
    let(:workflow) { create(:workflow) }
    let(:subjects) { create_list(:set_member_subject, 2) }

    context "with a user" do
      let(:user) { create(:user) }
      it 'should remove the subject given a user and workflow' do
        ues = create(:subject_queue,
                     user: user,
                     workflow: workflow,
                     set_member_subject_ids: subjects.map(&:id))
        SubjectQueue.dequeue(workflow,
                             [subjects.first.id],
                             user: user)
        expect(ues.reload.set_member_subject_ids).to_not include(subjects.first.id)
      end

      context "passing an empty set of sms_ids" do

        it 'should not raise an error' do
          expect {
            SubjectQueue.dequeue(workflow, [], user: user)
          }.to_not raise_error
        end

        it 'not attempt find the queue' do
          expect(SubjectQueue).to_not receive(:where)
          SubjectQueue.dequeue(workflow, [], user: user)
        end

        it 'should not call #dequeue_update' do
          expect_any_instance_of(SubjectQueue).to_not receive(:dequeue_update)
          SubjectQueue.dequeue(workflow, [], user: user)
        end

        it 'should return nil' do
          expect(SubjectQueue.dequeue(workflow, [], user: user)).to be_nil
        end
      end
    end
  end

  describe "#next_subjects" do
    let(:ids) { (0..60).to_a }
    let(:ues) { build(:subject_queue, set_member_subject_ids: ids) }

    context "when the queue has a user" do
      it 'should return a collection of ids' do
        expect(ues.next_subjects).to all( be_a(Fixnum) )
      end

      it 'should return 10 by default' do
        expect(ues.next_subjects.length).to eq(10)
      end

      it 'should accept an optional limit argument' do
        expect(ues.next_subjects(20).length).to eq(20)
      end

      it 'should return the first subjects in the queue' do
        expect(ues.next_subjects).to match_array(ues.set_member_subject_ids[0..9])
      end
    end

    context "when the queue does not have a user" do
      let(:ues) { build(:subject_queue, set_member_subject_ids: ids, user: nil) }

      it 'should return a collection of ids' do
        expect(ues.next_subjects).to all( be_a(Fixnum) )
      end

      it 'should return 10 by default' do
        expect(ues.next_subjects.length).to eq(10)
      end

      it 'should accept an optional limit argument' do
        expect(ues.next_subjects(20).length).to eq(20)
      end

      it 'should randomly sample from the subject_ids' do
        expect(ues.next_subjects).to_not match_array(ues.set_member_subject_ids[0..9])
      end
    end
  end

  describe "#below_minimum?" do
    let(:queue) { build(:subject_queue, set_member_subject_ids: subject_ids) }

    context "when less than 20 items" do
      let(:subject_ids) { create_list(:set_member_subject, 2).map(&:id) }

      it 'should return true' do
        expect(queue.below_minimum?).to be true
      end
    end

    context "when more than 20 items" do
      let(:subject_ids) { create_list(:set_member_subject, 21).map(&:id) }

      it 'should return false' do
        expect(queue.below_minimum?).to be false
      end
    end
  end
end
