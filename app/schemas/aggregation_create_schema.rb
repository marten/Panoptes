class AggregationCreateSchema < JsonSchema
  schema do
    type "object"
    description "An Aggregation for a subject"
    required "links"
    additional_properties false

    property "aggregation" do
      type "object"
    end

    property "links" do
      type "object"
      
      required "subject", "workflow"

      property "subject" do
        type "integer", "string"
      end
      
      property "workflow" do
        type "integer", "string"
      end
    end
  end
end
