module Ruql
  class Olx
    class ExportedEdxCourse

      require 'securerandom'      # for UUID generation
      require 'builder'

      def initialize(quiz, chapter_name, course_root, course_options, dryrun: false)
        @dryrun = dryrun
        @course_options = course_options
        @quiz = quiz
        @root = course_root
        verify_writable_dir(@problem_dir = File.join(@root, 'drafts', 'problem'))
        verify_writable_dir(@vertical_dir = File.join(@root, 'drafts', 'vertical'))
        verify_writable_dir(@sequential_dir = File.join(@root, 'sequential'))
        @chapter_file = find_chapter_file(chapter_name)
        @course_name = find_course_name
        @created_files = []       # to delete in case of error, or list created
        @modified_files = []
        @problem_ids = []
        @sequential_id = uuid()
        @vertical_id = uuid()
      end

      # Create a file containing a single problem and remember its UUID.
      def add_problem(xml_text)
        url = uuid()
        problem_file = File.join(@problem_dir, "#{url}.xml")
        begin
          File.open(problem_file, 'w') { |f|  f.puts xml_text  }
          @problem_ids << url
          @created_files << problem_file
        rescue StandardError => e
          cleanup
          raise IOError.new(:message => e.message)
        end
      end
      
      def add_quiz
        begin
          create_sequential
          create_vertical
          append_quiz_to_chapter
        rescue StandardError => e
          cleanup
          raise IOError.new(:message => e.message)
        end
      end

      def report
        report = ["Files created:"]
        @created_files.each { |f| report << "  #{f}" }
        report << "Files modified:"
        @modified_files.each { |f| report << "  #{f}" }
        cleanup if @dryrun
        report.join("\n")
      end

      private

      def uuid
        SecureRandom.hex(16)
      end

      def create_sequential
        file = File.join(@sequential_dir, "#{@sequential_id}.xml")
        File.open(file, 'w') do |fh|
          quiz_header = Builder::XmlMarkup.new(:target => fh, :indent => 2)
          quiz_header.sequential(@course_options)
        end
        @created_files << file
      end

      def create_vertical
        file = File.join(@vertical_dir, "#{@vertical_id}.xml")
        File.open(file, 'w') do |fh|
          vert = Builder::XmlMarkup.new(:target => fh, :indent => 2)
          vert.vertical(
            display_name: @quiz.title,
            index_in_children_list: 0,
            parent_url: "i4x://#{@course_name}/sequential/#{@sequential_id}") do
            @problem_ids.each do |prob|
              vert.problem(url_name: prob)
            end
          end
        end
        @created_files << file
      end

      # Verify that the given directory exists and is writable
      def verify_writable_dir(dir)
        unless (File.directory?(dir) && File.writable?(dir)) ||
            FileUtils.mkdir_p(dir)
          raise IOError.new("Directory #{dir} must exist and be writable")
        end
      end

      # Find the chapter .xml file for the chapter whose name matches 'name'.
      # If multiple chapters match, no guarantee on which gets picked.
      def find_chapter_file(name)
        regex = /<chapter display_name="([^"]+)">/i
        Dir.glob(File.join @root, 'chapter', '*.xml').each do |filename|
          first_line = File.open(filename, &:gets)
          return filename if (first_line =~ regex) && ($1 == name)
        end
        raise Ruql::OptionsError.new("Chapter '#{name}' not found in #{@root}/chapter/")
      end

      def append_quiz_to_chapter
        # insert just before last line
        chapter_markup = File.readlines(@chapter_file).insert(-2,
          %Q{  <sequential url_name="#{@sequential_id}"/>})
        File.open(@chapter_file, 'w') { |f|  f.puts chapter_markup  }
        @modified_files << @chapter_file
      end

      # Find the course's name ("#{org}/#{course}") from course.xml file
      def find_course_name
        course_markup = File.readlines(File.join(@root, 'course.xml')).join('')
        org = name = nil
        org = $1 if  course_markup =~ /<course.*org="([^"]+)"/
        name = $1 if course_markup =~ /<course.*course="([^"]+)"/
        raise Ruql::OptionsError.new("Cannot get course org and name from #{@root}/course.xml") unless org && name
        "#{org}/#{name}"
      end

      def cleanup
        # delete any created files; ignore errors during deletion
        @created_files.each { |f|  File.delete(f) rescue nil }
      end

    end
  end
end
