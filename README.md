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
    svn: https://svn.riouxsvn.com/gittime-example
  -
    xls: excel.xls
    # You can specify a fallback author if any field is empty:
    fallback:
      author: anonymous
  -
    csv: sample.csv
    fixed:
      author: jevon.wright
  # ... add more as necessary

# Different sources may have different ways of expressing
# authors. Use this to map source authors to a consistent author label.
# Case insensitive, and you can use regular expressions here.
authors:
  jevon:
    - jevon.*
    - Jevon.*
  # ... add more as necessary

# You can restrict reporting for only specific author labels:
# only:
#   authors:
#     - jevon

# For Git, xls, and csv sources, you can also categorise commits into categories.
# Each path changed in a commit is matched against the first category match
# found using path regexps, and given a (1.0/total number of paths changed)% weighting.
# These categories are then added together into each generated report.
categories:
  test:
    - spec
  config:
    - config.*yml
  docs:
    - README
  # an 'other' category will capture everything else

# For more complex setups, you can merge multiple files together.
# Each file is loaded and deep merged, but has the same schema as your config.yml.
# merge:
# - .file1.yml
# - .file2.yml
```

### Using an Excel format

Only `.xls` is supported, not `.xlsx`: see [spreadsheet gem](https://github.com/zdavatz/spreadsheet)

Each worksheet in the file must have a header row. For the best success,
provide the following header rows:

* `Modified by`
* `Modified at`
* `Message`
* `Path`

### Categories example

Using the "test", "config", and "docs" categories in the sample config above against the
[gittime](https://github.com/soundasleep/gittime) repository can result in:

| Month starting | Author | Blocks | test % | config % | docs % | other % |
|---|---|---|---|---|---|---|
| 2021-11-01 | jevon | 4 | 8.1% | 4.0% | 10.0% | 77.9% |
| 2022-01-01 | jevon | 1 | 0% | 0% | 0% | 100% |
| 2022-05-01 | jevon | 1 | 34.7% | 5.3% | 22.0% | 38.0% |

Showing that [in the month of November 2021](https://github.com/soundasleep/gittime/commits?since=2021-11-01&until=2021-11-30),
~8% was commits touched paths relating to tests, 4% to config, 10% to docs, and ~78% were uncategorised.

## Testing

```
bundle exec rake
```
