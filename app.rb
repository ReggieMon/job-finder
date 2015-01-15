# Note a few inconsistencies within the code are due to trying to adhere to
# a max length of 80 characters per line. For example, one line if-statements
# rather then a block if statement containing only one line. This compromise is
# a decision made to increase code readability.
require 'open-uri'
require 'json'

# Parses the tags within the job listing to find the location tag
def get_location(startup_tags)
  startup_tags.each do |tag|
    return tag['display_name'].to_s if tag['tag_type'] == 'LocationTag'
  end
end

# Parses the tags within the job listing to find the skill tags
def check_skills(startup_tags, candidate_skills)
  startup_tags.each do |tag|
    next if tag['tag_type'] != 'SkillTag'
    return true unless candidate_skills.index(tag['display_name'].downcase).nil?
  end
  false
end

# Prints out the jobs in a easily digested manner
def pretty_print(jobs)
  puts 'These jobs met the matching criteria.'
  jobs.each do |job|
    company = job['startup']['name']
    location = get_location(job['tags'])
    puts "  - #{company} located in #{location}"
  end
  puts 'Good luck with the job search!'
end

# Ensures that the command-line parameters are entered properly
if ARGV.length != 1
  if ARGV.length > 1
    puts 'Please enter one candidate at a time.'
  else
    puts 'Please include a candidate profile.'
  end
  exit
end

# Parses the json of the input file and stores it for future use
candidate_file = File.open(ARGV[0])
candidate = JSON.parse(candidate_file.read)
candidate_file.close

# Checks to see if the candidate is looking for a type of job
# ie: internship or full-time position
# without this information job matching wouldn't be meaningful
if candidate['expected_job_type'].nil?
  puts 'The candidate must at least have a preferrence for type of job.'
  exit
end

# Checks to see which portions of the input json contain data
# this is used to determine how precisely companies are mathed to the candidate
compatibility_markers = {}
compatibility_markers['salary'] = true unless candidate['expected_salary'].nil?
unless candidate['preferred_location'].nil?
  compatibility_markers['location'] = true
end
if !candidate['skillset'].nil? || candidate['skillset'].empty?
  compatibility_markers['skillset'] = true
end

# Allows the user to select how precise they want matching to be
max_compatibility = compatibility_markers.keys.length
compatibility_threshold = max_compatibility - 1
puts "The candidate has #{max_compatibility} compatibility markers"
puts "How many matching markers are you looking for? (1-#{max_compatibility})"
loop do
  compatibility_threshold = $stdin.gets.to_i
  if compatibility_threshold < max_compatibility && compatibility_threshold > 0
    break
  end
  puts "How many matching markers are you looking for? (1-#{max_compatibility})"
end
puts "#{compatibility_threshold} is set as the threshold. Beginning Matching"

response = open('http://api.angel.co/1/jobs').read
listing = JSON.parse(response)

# Variables needed to store matched companies and pagination location
potential_jobs = []
current_page = 1
finished = false
final_page = listing['last_page']

# The loop will loop through the job listings and determine how closely each
# matches the candidate. If a match is met that meets the users requirements,
# it is stored in the potential jobs. Due to the nature of the listing,
# the ten jobs selected will be the 10 most recent strong matches.
loop do
  listing['jobs'].each do |k, _|
    startup = k
    next if startup['job_type'] != candidate['expected_job_type']

    compatibility = 0

    # Contains some defense programming to avoid errors due to inconsistent
    # data
    if compatibility_markers['salary']
      min_salary = startup['salary_min']
      max_salary = startup['salary_max']
      if min_salary && max_salary
        if candidate['expected_salary'].between?(min_salary, max_salary)
          compatibility += 1
        end
      end
    end

    # Contains some defense programming to avoid errors due to inconsistent
    # data
    if compatibility_markers['location']
      location = candidate['preferred_location']
      if get_location(startup['tags']).downcase == location
        compatibility += 1
      elsif startup['remote_ok'] && candidate['willing_to_remote']
        compatibility += 1
      end
    end

    if compatibility_markers['skillset']
      compatibility += 1 if check_skills(startup['tags'], candidate['skillset'])
    end

    potential_jobs << startup if compatibility >= compatibility_threshold

    if potential_jobs.length == 10
      finished = true
      break
    end
  end
  break if finished
  break if current_page == final_page
  current_page += 1
  response = open("http://api.angel.co/1/jobs?page=#{current_page}").read
  listing = JSON.parse(response)
end

pretty_print(potential_jobs)
