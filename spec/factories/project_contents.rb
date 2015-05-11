# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :project_content do
    project
    language "en"
    title "A Test Project"
    description "Some Lorem Ipsum"
    introduction "MORE IPSUM"
    science_case "asdfasdf asdfasdf"
    education_content "asdfasdf asdfasdf"
    result "asdfasdf asdfasdf"
    faq "asdfasdf asdfasdf"
    team_members []
    url_labels({"0.label" => "Blog", "1.label" => "Twitter"})
    guide({ "example_1" => "A descripton of it" })
  end
end
