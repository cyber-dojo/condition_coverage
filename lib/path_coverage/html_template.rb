module PathCoverage
  # The HTML report's page templates, styles and scripts, kept
  # as files beside this one, and the filling of their slots.
  module HtmlTemplate
    DIR = File.join(__dir__, 'html')

    # The text of one of the report's template, style or script
    # files.
    def self.asset(name)
      File.read(File.join(DIR, name))
    end

    # The page template named name, its {{style}} the report's
    # style sheet, and each other {{name}} values[name].
    def self.page(name, values)
      fill(asset(name), values.merge('style' => asset('style.css')))
    end

    # template with each {{name}} replaced by values[name].
    def self.fill(template, values)
      template.gsub(/\{\{(\w+)\}\}/) do
        values.fetch(Regexp.last_match(1))
      end
    end
  end
end
