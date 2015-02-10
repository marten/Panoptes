class ClassificationSerializer
  include RestPack::Serializer
  attributes :id, :annotations, :created_at
  can_include :project, :user, :user_group, :workflow

  def add_links(model, data)
    data = super(model, data)
    data[:links][:subjects] = model.subject_ids.map(&:to_s)
    data
  end

  def self.links
    links = super
    links["#{key}.subjects"] = {
      type: "subjects",
      href: "/subjects/{#{key}.subjects}"
    }
    links
  end
end
