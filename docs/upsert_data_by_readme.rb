#!/usr/bin/env ruby

require 'git'
require 'kramdown'
require 'sanitize'

lang   = ARGV[0] || 'en'
target = if lang == 'en'
           '../README.en.md'
         elsif lang == 'ja'
           '../README.md'
         else
           puts "Need to pass [en|ja] to exec this task:"
           puts "Ex. $ bundle exec rake upsert_data_by_readme:en"
           puts "Ex. $ bundle exec rake upsert_data_by_readme:ja"
           puts "Ex. $ bundle exec rake upsert_data_by_readme"
           puts "    # This generate both data in English and Japanese"
           exit
         end
readme = IO.readlines(target)

# Remove existing files, parse README, and re-generate them
Dir.glob("./#{lang}/_posts/*.md").each { |filename| File.delete(filename) }

git = Git.open(`git rev-parse --show-toplevel`.chomp!)
start_parsing_flag = false
readme.each.with_index(1) do |line, index|
  # Operate start-of and end-of parsing table of lines in README.
  if start_parsing_flag == false
    start_parsing_flag = true if line.start_with? '| ---'
    next
  end
  break if line.start_with? '##' # Stop parsing if reached to next heading.

  # Generate Markdown files to publish from remotework.jp
  next unless line.include? '|'
  cells = line.gsub('\|', '&#124;').split '|'

  # Fetch latest commit info
  latest_commit_id  = `git blame #{target} -L #{index},+1 --porcelain --ignore-revs-file=docs/ignore_revs.txt`.strip.lines[0].split.first
  latest_commit_at  = git.gcommit(latest_commit_id).author_date.strftime('%Y-%m-%d')
  latest_commit_url = 'https://github.com/remote-jp/remote-in-japan/commit/' + latest_commit_id

  # Fetch company name and its link from 1st cell
  name_and_link = Kramdown::Document.new(cells[1]).root.children[0].children[0]
  name  = name_and_link.children[0].value.strip
  link  = name_and_link.attr['href']
  id    = name.gsub(' ', '_')
    .gsub('＆', 'and')
    .gsub('&',  'and')
    .gsub('（', '(')
    .gsub('）', ')')
    .delete(".,").downcase

  # Fetch company description from 2nd cell and categories from the other cell(s)
  description    = Kramdown::Document.new(cells[2].strip).to_html.strip
  is_full_remote = cells[3].include?('ok') ? 'full_remote' : ''

  # Generate Jekyll post with fetched company data above
  company = <<~COMPANY_PAGE
    ---
    layout: post
    lang: #{lang}
    permalink: /#{lang}/#{id}
    title: #{name}
    description: '#{Sanitize.clean(CGI.unescapeHTML description).strip}'
    categories: #{is_full_remote}
    link: #{link}
    commit_url: #{latest_commit_url}
    commit_at:  #{latest_commit_at}
    ---

    #{CGI.unescapeHTML description}
  COMPANY_PAGE

  #company << "by: John Doe\n"                    # Not being used
  #company << "image: ''\n"                       # Not being used

  IO.write("./#{lang}/_posts/2020-02-22-#{id}.md", company)
  puts "Upsert: ./#{lang}/_posts/2020-02-22-#{id}.md"
end
puts ''
