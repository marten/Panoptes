require 'spec_helper'

describe User, type: :model do
  let(:user) { create(:user) }
  let(:activatable) { user }
  let(:owner) { user }
  let(:owned) { create(:project, owner: user.identity_group) }

  it_behaves_like "activatable"
  it_behaves_like "is an owner"

  describe "links" do
    it "should allow membership links to any user" do
      expect(User).to link_to(Membership).with_scope(:all)
    end

    it "should allow user_gruop links to any user" do
      expect(User).to link_to(UserGroup).with_scope(:all)
    end
  end

  describe '::from_omniauth' do
    let(:auth_hash) { OmniAuth.config.mock_auth[:facebook] }

    shared_examples 'new user from omniauth' do
      let(:user_from_auth_hash) do
        user = User.from_omniauth(auth_hash)
      end

      it 'should create a new valid user' do
        expect(user_from_auth_hash).to be_valid
      end

      it 'should create a user with the same details' do
        expect(user_from_auth_hash.email).to eq(auth_hash.info.email)
      end

      it 'should create a user with a display_name' do
        expect(user_from_auth_hash.display_name).to eq(auth_hash.info.name.gsub(/\s/, '_'))
      end

      it 'should create a user with a authorization' do
        expect(user_from_auth_hash.authorizations).to all( be_an(Authorization) )
      end
    end

    context 'a new user with email' do
      it_behaves_like 'new user from omniauth'
    end

    context 'a user without an email' do
      let(:auth_hash) { OmniAuth.config.mock_auth[:facebook_no_email] }

      it 'should not have an email' do
        expect(User.from_omniauth(auth_hash).email).to be_nil
      end

      it_behaves_like 'new user from omniauth'
    end

    context 'an existing user' do
      let!(:omniauth_user) { create(:omniauth_user) }

      it 'should return the existing user' do
        expect(User.from_omniauth(auth_hash)).to eq(omniauth_user)
      end
    end

    context 'an invalid user' do
      it 'should raise an exception' do
        create(:user, email: 'examplar@example.com')
        auth_hash = OmniAuth.config.mock_auth[:gplus]
        expect{ User.from_omniauth(auth_hash) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe "#signup_project" do
    let(:project) { create(:project) }

    it "should not find any associated project" do
      expect(user.signup_project).to be_nil
    end

    context "when the project_id is set" do
      let!(:user) { create(:user, project_id: project.id) }

      it "should find the associated project" do
        expect(user.signup_project).to eq(project)
      end
    end
  end

  describe '#display_name' do
    it 'should validate presence' do
      expect(build(:user, display_name: "")).to_not be_valid
    end

    it 'should not have whitespace' do
      expect(build(:user, display_name: " asdf asdf")).to_not be_valid
    end

    it 'should not have a dollar sign' do
      expect(build(:user, display_name: "$asdfasdf")).to_not be_valid
    end

    it 'should not have an at sign' do
      expect(build(:user, display_name: "@asdfasdf")).to_not be_valid
    end

    context "migrated users" do
      let(:user) { build(:user, migrated: true) }

      it 'should validate presence' do
        user.display_name = ""
        expect(user).to_not be_valid
      end

      it 'should not have whitespace' do
        user.display_name = " asdf asdf"
        expect(user).to be_valid
      end

      it 'should not have a dollar sign' do
        user.display_name = "$asdfasdf"
        expect(user).to be_valid
      end

      it 'should not have an at sign' do
        user.display_name = "@asdfasdf"
        expect(user).to be_valid
      end
    end

    it 'should have non-blank error' do
      user = build(:user, display_name: "")
      user.valid?
      expect(user.errors[:display_name]).to include("can't be blank")
    end

    it 'should validate uniqueness to enable filtering by the display name' do
      display_name = 'Mista_Bob_Dobalina'
      expect{ create(:user, display_name: display_name) }.to_not raise_error
      expect{ create(:user, display_name: display_name.upcase, email: 'test2@example.com') }.to raise_error
      expect{ create(:user, display_name: display_name.downcase, email: 'test3@example.com') }.to raise_error
    end

    it "should have the correct case-insensitive uniqueness error" do
      user = create(:user)
      dup_user = build(:user, display_name: user.display_name.upcase)
      dup_user.valid?
      expect(dup_user.errors[:display_name]).to include("has already been taken")
    end
  end

  describe '#email' do

    context "when a user is setup" do
      let(:user) { create(:user, email: 'test@example.com') }

      it 'should raise an error trying to save a duplcate' do
        expect{ create(:user, email: user.email.upcase) }.to raise_error
      end

      it 'should validate case insensitive uniqueness' do
        dup = build(:user, email: user.email.upcase)
        dup.valid?
        expect(dup.errors[:email]).to include("has already been taken")
      end
    end

    context "when a user is disabled and has no email" do
      subject { build(:user, email: nil, activated_state: :inactive) }

      it { is_expected.to be_valid }
    end
  end

  describe '#valid_email' do
    let(:user) { build(:user, email: 'isitvalid@example.com') }

    it 'should set the valid_email field to true' do
      expect(user.valid_email).to be_truthy
    end

    describe "setting the field to nil" do
      before(:each) do
        user.valid_email = nil
      end

      it 'should not be valid' do
        expect(user.valid?).to be_falsey
      end

      it 'should have the correct error message' do
        user.valid?
        expect(user.errors[:valid_email]).to include("must be true or false")
      end
    end
  end

  describe "#build_identity_group" do
    let(:user) { build(:user, build_group: false) }

    context "when a user has a valid display_name" do
      before(:each) do
        user.build_identity_group
        user.save!
        user.reload
      end

      it 'should a new membership with identity set to true' do
        expect(user.identity_membership.identity).to eq(true)
      end

      it 'should have a group with the same display_name as the user display_name' do
        expect(user.identity_group.display_name).to eq(user.display_name)
      end

      it 'should raise error if a user has an identity group' do
        user = create(:user)
        expect{ user.build_identity_group }.to raise_error(StandardError, "Identity Group Exists")
      end
    end

    context "when a user_group with the same name in different case exists" do
      let!(:user_group) { create(:user_group, display_name: user.display_name.upcase) }

      it "should not be valid" do
        expect do
          user.build_identity_group
          user.save!
        end.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "should have the correct error message on the identity_group attribute" do
        user.build_identity_group
        user.valid?
        expect(user.errors[:"identity_group.display_name"]).to include("has already been taken")
      end
    end

    context "when the identity group is missing" do

      it "should not be valid" do
        expect(user.valid?).to be_falsy
      end

      it "should have the correct error message on the identity_group association" do
        user.valid?
        expect(user.errors[:identity_group]).to include("can't be blank")
      end
    end
  end

  describe "#password_required?" do
    it 'should require a password when creating with a new user' do
      expect{ create(:user, password: "password1") }.to_not raise_error
      expect{ create(:user, password: nil) }.to raise_error
    end

    it 'should not require a password when creating a user from an import' do
      attrs = {display_name: "Mr.T", hash_func: 'sha1', email: "test@example.com"}
      expect do
        User.create!(attrs) do |u|
          u.build_identity_group
        end
      end.to_not raise_error
    end
  end

  describe "#valid_password?" do
    it 'should validate user with bcrypted password' do
      expect(create(:user).valid_password?('password')).to be_truthy
    end

    it 'should validate length of user passwords' do
      user_errors = ->(attrs){ User.new(attrs).tap{ |u| u.valid? }.errors }
      expect(user_errors.call(password: 'ab12')).to have_key :password
      expect(user_errors.call(password: 'abcd1234')).to_not have_key :password
      expect(user_errors.call(migrated: true, password: 'ab')).to have_key :password
      expect(user_errors.call(migrated: true, password: 'ab12')).to_not have_key :password
    end

    context "with the old sha1 hashing alg" do
      let(:user) do
        u = create(:insecure_user)
        u.hash_func = 'sha1'
        u.save
        u
      end

      it 'should validate imported user with sha1+salt password' do
        expect(user.valid_password?('tajikistan')).to be_truthy
      end

      it 'should not validate an imported user with an invalid password' do
        expect(user.valid_password?('nottheirpassword')).to be_falsey
      end

      it 'should update an imported user to use bcrypt hashing' do
        user.valid_password?('tajikistan')
        expect(user.hash_func).to eq("bcrypt")
      end
    end
  end

  describe "#admin" do
    let(:user) { build(:user) }

    it "should be false by default" do
      expect(user.admin).to be false
    end
  end

  describe "#active_for_authentication?" do
    let(:user) { create(:user) }

    it "should return true for an active user" do
      expect(user.active_for_authentication?).to eq(true)
    end

    it "should be false for a disabled user" do
      user.disable!
      expect(user.active_for_authentication?).to eq(false)
    end
  end

  describe "#languages" do
    context "when no languages are set" do

      it "should return an emtpy array for no set languages" do
        user = build(:user)
        expect(user.languages).to match_array([])
      end
    end
  end

  describe "#projects" do
    let(:user) { create(:project_owner) }

    it "should have many projects" do
      expect(user.projects).to all( be_a(Project) )
    end
  end

  describe "#memberships" do
    let(:user) { create(:user_group_member) }

    it "should have many user group members" do
      expect(user.memberships).to all( be_a(Membership) )
    end
  end

  describe "#user_groups" do
    let(:user) { create(:user_group_member) }

    it "should be a member of many user groups" do
      expect(user.user_groups).to all( be_a(UserGroup) )
    end
  end

  describe "#collections" do
    let(:user) { create(:user_with_collections) }

    it "should have many collections" do
      expect(user.collections).to all( be_a(Collection) )
    end
  end

  describe "#classifications" do
    let(:relation_instance) { user }

    it_behaves_like "it has a classifications assocation"
  end

  describe "#classifcations_count" do
    let(:relation_instance) { user }

    it_behaves_like "it has a cached counter for classifications"
  end

  describe "::memberships_for" do
    let(:user) { create(:user_group_member) }
    let(:query_sql) { user.memberships_for(action, test_class).to_sql }
    let(:test_class) { Project }
    let(:action) { :update }

    context "supplied class" do
      it 'should query for editor roles for the supplied class' do
        expect(query_sql).to match(/project_editor/)
      end
    end

    context "no class" do
      let(:test_class) { nil }
      it 'should not add additional roles' do
        expect(query_sql).to_not match(/editor/)
      end
    end

    context "action is show" do
      let(:action) { :show }

      it 'should query for group_admin' do
        expect(query_sql).to match(/group_admin/)
      end

      it 'should query for group_member' do
        expect(query_sql).to match(/group_member/)
      end
    end

    context "action is index" do
      let(:action) { :index }

      it 'should query for group_admin' do
        expect(query_sql).to match(/group_admin/)
      end

      it 'should query for group_member' do
        expect(query_sql).to match(/group_member/)
      end
    end

    context "action is not show or index" do
      it 'should query for group_admin' do
        expect(query_sql).to match(/group_admin/)
      end

      it 'should not query for group member' do
        expect(query_sql).to_not match(/group_member/)
      end
    end
  end

  describe "::scope_for" do
    let(:users) do
      [ create(:user, activated_state: 0),
        create(:user, activated_state: 0),
        create(:user, activated_state: 1) ]
    end

    let(:actor) { ApiUser.new(users.first) }

    context "action is show" do
      it 'should return the active users' do
        expect(User.scope_for(:show, actor)).to match_array(users.values_at(0,1))
      end
    end

    context "action is index" do
      it 'should return the active users' do
        expect(User.scope_for(:show, actor)).to match_array(users.values_at(0,1))
      end
    end

    context "action is destroy or update" do
      it 'should only return the acting user' do
        expect(User.scope_for(:destroy, actor)).to match_array(users.first)
      end
    end
  end

  describe "has_finished?" do
    let(:user) { create(:user) }
    subject { user.has_finished?(workflow) }

    context 'when the user has classified all subjects in a workflow' do
      let(:workflow) do
        workflow = create(:workflow_with_subjects)
        ids = workflow.subject_sets.flat_map(&:subjects).map(&:id)
        create(:user_seen_subject, user: user, workflow: workflow, subject_ids: ids)
        workflow
      end

      it { is_expected.to be true }
    end

    context 'when the user not finished classifying a workflow' do
      let(:workflow) do
        workflow = create(:workflow_with_subjects)
        create(:user_seen_subject, user: user, workflow: workflow, subject_ids: [])
        workflow
      end

      it { is_expected.to be false }
    end
  end

  describe "#password" do
    it "should set a user's hash_func to bcrypt" do
      u = build(:insecure_user)
      u.password = 'newpassword'
      expect(u.hash_func).to eq('bcrypt')
    end
  end

  describe "#uploaded_subjects" do
    it 'should list the subjects a user has uploaded' do
      uploader = create(:user_with_uploaded_subjects)
      expect(uploader.uploaded_subjects).to all( be_a(Subject) )
    end
  end

  describe "#uploaded_subjects_count" do
    it 'should have a count of the subjects a user has uploaded' do
      uploader = create(:user_with_uploaded_subjects)
      expect(uploader.uploaded_subjects_count).to eq(2)
    end
  end
end
