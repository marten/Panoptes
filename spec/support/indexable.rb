RSpec.shared_examples "is indexable" do
  let(:resource_ids) do
    created_instance_ids(api_resource_name).map(&:to_i)
  end

  let(:ips) do
    defined?(index_params) ? index_params : {}
  end

  before(:each) do
    default_request scopes: scopes, user_id: authorized_user.id if authorized_user
  end

  def run_get
    get :index, ips
  end

  it 'should return results', :aggregate_failures do
    run_get
    expect(response.status).to eq 200
    expect(json_response[api_resource_name].length).to eq n_visible
  end

  context "with response" do
    before { run_get }
    it_behaves_like 'an api response'
    it_behaves_like 'an indexable etag response'
  end
end
