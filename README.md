# gittime

A configurable tool to track work effort by committers on Git and Subversion repositories, Excel sheets, and CSV files.

Spiritual successor to [svntime](https://github.com/soundasleep/svntime)

## Requirements

* Ruby 2.6+ or 3.0+
* `git` if you want to use git sources
* `svn` if you want to use subversion sources

## Running

```
bundle install
bundle exec ruby generate.rb --config path/to/config.yml
```

Will generate the following files:

| Filename    | Description |
| ----------- | ----------- |
| `revisions.csv` | An unfiltered list of all data points (revisions) |
| `revisions-with-authors.csv` | Filtered with `authors:` config below, and duplicate entries removed |
| `blocks.csv` | `before` and `after` applied to each date, and contiguous blocks are merged; may span multiple months |
| `blocks-by-month.csv` | Blocks split across month boundaries |
| `work-by-month.csv` | The number of seconds in each block, per month and per author |

## Config file format

You can create a new config file by using the `--init` flag, or copy the sample file below.

```yaml
# Each source can have a default before/after set
default_source:
  before: 1 hour
  after: 1 hour

# List all the different sources you want to parse
# Available sources:
#   - git
#   - svn
#   - xls
#   - csv
sources:
  -
    git: https://github.com/soundasleep/gittime
    # You can customise before/after here, based on your commit style:
    before: 2 hours
    after: 30 seconds
    # You can select only commits that match a path (each of these are a regexp):
    # only:
    #   - \.github/
    #   - README.*
  -
    svn: https://github.com/soundasleep/svntime
  -
    xls: excel.xls
  -
    csv: sample.csv
    fixed:
      author: jevon.wright
  # ... add more as necessary

# Finally, different sources may have different ways of expressing
# authors. Use this to map source authors to a consistent author label.
# Case insensitive, and you can use regular expressions here.
authors:
  jevon:
    - jevon.*
    - Jevon.*
  # ... add more as necessary
```

### Using an Excel format

Only `.xls` is supported, not `.xlsx`: see [spreadsheet gem](https://github.com/zdavatz/spreadsheet)

Each worksheet in the file must have a header row. For the best success,
provide the following header rows:

* `Modified by`
* `Modified at`
* `Message`

## Testing

```
bundle exec rake
```
