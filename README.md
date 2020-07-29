# Ruql::Olx

This formatter requires [ruql](https://github.com/saasbook/ruql) and
allows formatting RuQL quizzes as OLX or Open Learning XML, a format
developed and used by [edX](https://edx.org) for rendering course assets.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruql-olx'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ruql-olx

## Usage

The simplest usage is `ruql olx --sequential seq.xml quizfile.rb > output.olx`.

The OLX representation of all the questions in `quizfile.rb` will be
left in the file `output.olx`.

The file `seq.xml` will contain the necessary XML markup for the quiz
metadata itself, such as time limit, the fact that it's graded, etc.
This XML snippet needs to be copied into the correct file in the
appropriate `sequentials` subdirectory of an edX course export.
If the `--sequential` option is omitted, no such file is created.

## Limitations of current version

The time limit is computed as 1 point per minute plus 5
minutes of slop, rounded up to the nearest 5 minutes.

The other metadata items (graded or not, etc.) cannot be customized
except by manually editing the `seq.xml` file.

Normally, RuQL questions that have the same `group` attribute value
are considered a "pool" of questions from which a particular subset
are randomly used each time a quiz is generated.  The current version
of the gem ignores this field and simply outputs *all* questions in
the `quizfile.rb`.

    
## Development/Contributing

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

Bug reports and pull requests are welcome on GitHub at https://github.com/saasbook/ruql-olx. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the Ruql::Olx project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/saasbook/ruql-olx/blob/master/CODE_OF_CONDUCT.md).
