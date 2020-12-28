module Ruql
  class Olx
    require 'builder'
    require 'erb'
    
    attr_reader :output

    def initialize(quiz,options={})
      @quiz = quiz
      @dryrun = !! options.delete('--dry-run')
      if (chapter = options.delete('--chapter'))
        root = options.delete('--root') || Dir.getwd
        @edx = Ruql::Olx::ExportedEdxCourse.new(quiz, chapter, root,
          # quiz options for edX
          {
            is_time_limited: "true",
            default_time_limit_minutes: self.time_limit,
            display_name: quiz.title,
            exam_review_rules: "",
            is_onboarding_exam: "false",
            is_practice_exam: "false",
            is_proctored_enabled: "false"
          },
          dryrun: @dryrun)
      end
      @question_number = 1
      @groupselect = (options.delete('--group-select') || 1_000_000).to_i
      @output = ''
      @h = nil                  # XML Builder object
    end

    def self.allowed_options
      opts = [
        ['--chapter', GetoptLong::REQUIRED_ARGUMENT],
        ['--root', GetoptLong::REQUIRED_ARGUMENT],
        ['--group-select', GetoptLong::REQUIRED_ARGUMENT],
        ['--dry-run', GetoptLong::NO_ARGUMENT]
      ]
      help = <<eos
The OLX renderer modifies an exported edX course tree in place to incorporate the quiz.
It supports these options:
  --chapter '<name>'
      Insert the quiz as the last child (sequential) of the chapter whose display name
      is <name>.  Use quotes as needed to protect spaces/special characters in chapter name.
      If multiple chapter names match, the quiz will end up in one of them.
      If this option is omitted, the problem XML will instead be written to standard output,
      and no files will be created or modified.
  --root=<path>
      Specify <path> as root directory of the edX course export.  If omitted, default is '.'
  --dry-run
      Only valid with --chapter: report names of created files but then delete them from export.
      The files are created and deleted, so not a true dry run, but leaves the export intact
      while verifying that the changes are possible.
  --group-select=<n>
      If multiple RuQL questions share the same 'group' attribute, include at most n of them
      in the output.  If omitted, defaults to "all questions in group".
eos
      return [help, opts]
    end

    def render_quiz
      # caller expects to find "quiz content" in @output, but if we modified edX, then
      # output is just the report of what we did.
      @groups_seen = Hash.new { 0 }
      @group_count = 0
      render_questions
      if @edx
        @edx.add_quiz
        @output = @edx.report
      end
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
        question_xml = ''
        @h = Builder::XmlMarkup.new(:target => question_xml, :indent => 2)
        # have we maxed out the number of questions per group for this group?
        next unless more_in_group?(q)
        case q
        when MultipleChoice then render_multiple_choice(q)
        when SelectMultiple then render_select_multiple(q)
        else
          raise Ruql::QuizContentError.new "Unknown question type: #{q}"
        end
        # question_xml now contains the XML of the given question...
        if @edx
          @edx.add_problem(question_xml)
        else
          @output << question_xml << "\n"
        end
        @question_number += 1
      end
    end

    def more_in_group?(q)
      group = q.question_group
      # OK to proceed if q. has no group, OR if we haven't used @groupselect questions in group
      return true if group.to_s == ''
      @groups_seen[group] += 1
      return (@groups_seen[group] <= @groupselect)
    end

    def render_multiple_choice(q)
      @h.problem(display_name: "Question #{@question_number}", markdown: 'null') do
        @h.multiplechoiceresponse do
          render_question_text(q)
          @h.choicegroup(type: 'MultipleChoice') do
            render_answers(q)
          end
        end
      end
    end

    def render_select_multiple(q)
      @h.problem(display_name: "Question #{@question_number}", markdown: 'null') do
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

  end
end
