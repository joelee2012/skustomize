require 'simplecov-cobertura'


SimpleCov.start do
  formatter SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::SimpleFormatter,
      SimpleCov::Formatter::HTMLFormatter
    ])
  minimum_coverage 5
  add_filter "/tests/"
  add_filter "/.git/"
end
