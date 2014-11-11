require 'spec_helper'

RSpec.describe TasksVisitors::ExtractStrings do
  let(:task_hash) do
    {
     interest: {
                type: 'drawing',
                question: 'Color some points',
                tools: [
                        {value: 'red', label: 'Red', type: 'point', color: 'red'},
                        {value: 'green', label: 'Green', type: 'point', color: 'lime'},
                        {value: 'blue', label: 'Blue', type: 'point', color: 'blue'}
                       ],
                next: 'shape'
               },
     shape: {
             type: 'multiple',
             question: 'What shape is this galaxy?',
             answers: [
                       {value: 'smooth', label: 'Smooth'},
                       {value: 'features', label: 'Features'},
                       {value: 'other', label: 'Star or artifact'}
                      ],
             required: true,
             next: 'roundness'
            },
     roundness: {
                 type: 'single',
                 question: 'How round is it?',
                 answers: [
                           {value: 'very', label: 'Very...', next: 'shape'},
                           {value: 'sorta', label: 'In between'},
                           {value: 'not', label: 'Cigar shaped'}
                          ],
                 next: nil}
    }
  end

  describe "#visit" do
    context "given an array collector" do
      let(:collector) { [] }
      subject do
        TasksVisitors::ExtractStrings.new(collector)
      end

      before(:each) do
        subject.visit(task_hash)
      end

      it 'should substitute question strings with TaskIndex objects' do
        question_vals = task_hash.values_at(:interest, :shape, :roundness)
          .map { |hash| hash[:question] }
        expect(question_vals).to include(0, 4, 8)
      end

      it 'should substitute label strings with TaskIndex objects' do
        label_vals = task_hash.values_at(:interest, :shape, :roundness)
          .flat_map do |hash|
            key = hash.has_key?(:answers) ? :answers : :tools
            hash[key].map { |h| h[:label] }
          end

        expect(label_vals).to include(1,2,3,5,6,7,9,10,11)
      end

      it 'should set the key to the index of the substituted string' do
        expect(task_hash[:interest][:question]).to eq(0)
      end

      it 'should populate the collector with strings' do
        expect(collector).to include("Color some points",
                                     'Red',
                                     'How round is it?',
                                     "Cigar shaped")
      end
    end

    context "without an array collector" do

      it 'should return the strings via the collect method' do
        subject.visit(task_hash)
        expect(subject.collector).to include("Color some points",
                                     'Red',
                                     'How round is it?',
                                     "Cigar shaped")
      end
    end
  end
end