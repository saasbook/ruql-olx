module Ruql
  class Olx
    require 'builder'
    require 'erb'
    
    attr_reader :output

    def initialize(quiz,options={})
      @sequential = options.delete('--sequential')
      @output = ''
      @quiz = quiz
      @h = Builder::XmlMarkup.new(:target => @output, :indent => 2)
    end

    def self.allowed_options
      opts = [
        ['--sequential', GetoptLong::REQUIRED_ARGUMENT] 
      ]
      help = <<eos
The OLX renderer supports these options:
  --sequential <filename>.xml
      Write the OLX quiz header (includes quiz name, time limit, etc to <filename>.xml.
      This information can be copy-pasted into the appropriate <sequential> OLX element
      in a course export.  If omitted, no quiz header .xml file is created.
eos
      return [help, opts]
    end

    def render_quiz
      render_questions
      write_quiz_header if @sequential
      @output
    end

    # write the quiz header
    def write_quiz_header
      fh = File.open(@sequential, 'w')
      @quiz_header = Builder::XmlMarkup.new(:target => fh, :indent => 2)
      @quiz_header.sequential(
        is_time_limited: "true",
        default_time_limit_minutes: self.time_limit,
        display_name: @quiz.title,
        exam_review_rules: "",
        is_onboarding_exam: "false",
        is_practice_exam: "false",
        is_proctored_enabled: "false")
      fh.close
    end

    def time_limit
      minutes_per_point = 1
      slop = 5 # extra time for setup, etc
      limit =  @quiz.points.to_i * minutes_per_point + slop
      # round up to next 5 minutes
      limit += 5 - (limit % 5)
      limit
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
        @h.choice(correct: answer.correct?)  { |l| l << answer.answer_text }
      end
    end

    def render_question_text(q)
      qtext = q.question_text
      qtext << " Select ALL that apply." if q.multiple
      @h.label { |l| l << qtext }
    end

    def quiz_header
      self
    end

  end
end
