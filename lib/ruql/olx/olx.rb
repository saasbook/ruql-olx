module Ruql
  class Olx
    require 'builder'
    require 'erb'
    
    attr_reader :output

    def initialize(quiz,options={})
      @gem_root = Gem.loaded_specs['ruql-olx'].full_gem_path rescue '.'
      @output = ''
      @quiz = quiz
      @raw = nil # temp var reset for each question
      @h = Builder::XmlMarkup.new(:target => @output, :indent => 2)
    end

    def self.allowed_options
      opts = []
      help = ''
      return [help, opts]
    end

    def render_quiz
      render_questions
      @output
    end

    # this is what's called when the OLX template yields:
    def render_questions
      @quiz.questions.each do |q|
        case q
        when MultipleChoice then render_multiple_choice(q)
        when SelectMultiple then render_select_multiple(q)
        else
          raise Ruql::QuizContentError.new "Unknown question type: #{q}"
        end
      end
    end

    # //This Question has Html formatting in the answer
    # <problem display_name="Multiple Choice" markdown="null">
    #   <multiplechoiceresponse>
    #     <label>Which condition is necessary when using Ruby's collection methods such as map and reject?</label>
    #     <description> </description>
    #     <choicegroup type="MultipleChoice">
    #       <choice correct="false">The collection on which they operate must consist of objects of the same type.</choice>
    #       <choice correct="true">The collection must respond to <pre> &lt;tt&gt;each&lt;/tt&gt; </pre></choice>
    #       <choice correct="false">Every element of the collection must respond to <pre> &lt;tt&gt;each&lt;/tt&gt; </pre></choice>
    #       <choice correct="false">The collection itself must be one of Ruby's built-in collection types, such as <pre> &lt;tt&gt;Array&lt;/tt&gt; or &lt;tt&gt;Set&lt;/tt&gt; </pre></choice>
    #     </choicegroup>
    #   </multiplechoiceresponse>
    # </problem>
    def render_multiple_choice(q)
      @h.problem(display_name: 'MultipleChoice', markdown: 'null') do
        @h.multiplechoiceresponse do
          render_question_text(q)
          @h.choicegroup(type: 'MultipleChoice') do
            render_question_text(q)
            render_answers(q)
          end
        end
      end
      @output << "\n\n"
    end

    def render_select_multiple(q)
      @h.problem(display_name: 'Checkboxes', markdown: 'null') do
        @h.choiceresponse do
          render_question_text(q)
          @h.checkboxgroup do
            render_answers(q)
          end
        end
      end
    end

    def render_answers(q)
      q.answers.each do |answer|
        if q.raw?
          @h.choice(correct: answer.correct?)  { |l| l << answer.answer_text }
        else
          @h.choice(answer.answer_text, correct: answer.correct?)
        end
      end
    end

    def render_question_text(q)
      qtext = q.question_text
      qtext << " Select ALL that apply." if q.multiple
      if q.raw?
        @h.label do
          qtext.each_line do |p|
            @h.p do |par|
              par << p # preserves HTML markup
            end
          end
        end
      else
        @h.label qtext
      end
    end

    def quiz_header
      self
    end

  end
end
