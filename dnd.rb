require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

def load_character_file
  YAML.load_file("characters.yml")
end

def load_character_data
  load_character_file[session[:username]][session[:char]]
end

def load_login_data
  YAML.load_file("users.yml")
end

def determine_level(exp)
  case exp
  when 0..299 then 1
  when 300..899 then 2
  when 900..2699 then 3
  when 2700..6499 then 4
  when 6500..13999 then 5
  when 14000..22999 then 6
  when 23000..33999 then 7
  when 34000..47999 then 8
  when 48000..63999 then 9
  when 64000..84999 then 10
  end
end

def breakout_roll_message(total)
  case
  when total.size == 2 && total[0] == 20
    rolls = total.join(", plus ")
    return "You rolled a #{rolls} is #{total.sum}. A natural twenty!? Damn son!"
  when total.size == 2 && total[0] == 1
    rolls = total.join(", plus ")
    return "You rolled a #{rolls} is #{total.sum}. A natural one!? This is gonna hurt!"
  when total.size == 2 then rolls = total.join(", plus ")
  when total.size == 3
    rolls = total[0..1].join(" and a ")
    rolls << ", plus #{total[-1]}"
  else
    rolls = total[0..-3].join(", ")
    rolls << ", and a #{total[-2]}, plus #{total[-1]}"
  end

  "You rolled a #{rolls} is #{total.sum}"
end

def signed_in?
  session[:username]
end

def check_sign_in_status
  redirect "/users/signin" unless signed_in?
end

################# Index Route ##################

get "/" do
  check_sign_in_status


  selected_character = load_character_data
  @name = session[:char]
  @experience = selected_character["experience"]
  @level = determine_level(@experience)
  @race = selected_character["race"]
  @class = selected_character["class"]
  @abilities = selected_character["abilities"]
  @skills = selected_character["skills"]

  erb :index
end

################# Sign In Routes ##################

get "/users/new" do
  erb :newuser
end

def check_user(current_users, username, password)
  if current_users.keys.include?(username)
    session[:message] = "This username already exists."
  elsif username.empty? || password.empty?
    session[:message] = "Username and password must not be blank."
  end
end

post "/users/new" do
  current_users = load_login_data
  username = params[:username].strip
  password = params[:password].strip
  session[:message] = check_user(current_users, username, password)
  if session[:message]
    status 422
    erb :newuser
  else
    current_users[username] = BCrypt::Password.create(password).to_s
    File.open("users.yml", 'w+') do |f|
      f.write(current_users.to_yaml)
    end
    session[:message] = "#{username} registered successfully."
    redirect "/"
  end
end


get "/users/signin" do
  erb :signin
end

def valid_credentials?(username, password)
  credentials = load_login_data

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

post "/users/signin" do

  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome #{username}!"
    redirect "/choose"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :signin
  end
end

get "/users/signout" do
  session.delete(:username)
  session[:message] = "You have signed out."
  redirect "/users/signin"
end


################# Choose and Create Character ##################

get "/choose" do
  @single_users_characters = load_character_file[session[:username]] || {}

  erb :choose
end

post "/choose" do
  session[:char] = params[:char]
  redirect "/"
end

get "/createcharacter" do
  erb :create_char
end

def roll_new_ability_score
  rolls = []
  4.times do
    rolls << rand(1..7)
  end

  rolls.sort[1..3].sum
end


post "/createcharacter" do
  char_name = params[:char_name]
  char_race = params[:char_race]
  char_class = params[:char_class]

  str = roll_new_ability_score
  dex = roll_new_ability_score
  con = roll_new_ability_score
  int = roll_new_ability_score
  wis = roll_new_ability_score
  cha = roll_new_ability_score

  character_info  = {char_name =>
    {"experience"=>0,
     "race"=>char_race,
     "class"=>char_class,
     "abilities"=>
      {"strength"=>str, "dexterity"=>dex, "constitution"=>con, "intelligence"=>int, "wisdom"=>wis, "charisma"=>cha},
     "skills"=>
      {"Acrobatics"=>0,
       "Animal Handling"=>0,
       "Arcana"=>0,
       "Athletics"=>0,
       "Deception"=>0,
       "History"=>0,
       "Insight"=>0,
       "Intimidation"=>0,
       "Investigation"=>0,
       "Medicine"=>0,
       "Nature"=>0,
       "Perception"=>0,
       "Performance"=>0,
       "Persuation"=>0,
       "Religion"=>0,
       "Slight of Hand"=>0,
       "Stealth"=>0,
       "Survival"=>0}}}

  all_characters = load_character_file

  if all_characters.keys.include?(session[:username])
    all_characters[session[:username]].merge!(character_info)
  else
    all_characters[session[:username]] = character_info
  end

  File.open("characters.yml", 'w+') do |f|
      f.write(all_characters.to_yaml)
    end

  session[:char] = char_name

  redirect "/"
end

################# Edit Attribute Routes ##################

get "/expedit" do
  check_sign_in_status
  selected_character = load_character_data
  @value = selected_character["experience"]

  erb :edit_exp
end

post "/expedit" do
  check_sign_in_status

  updated_value = params[:newvalue].to_i

  all_characters = load_character_file
  selected_character = all_characters[session[:username]][session[:char]]

  selected_character["experience"] = updated_value

  File.open("characters.yml", 'w+') do |f|
    f.write(all_characters.to_yaml)
  end

  redirect "/"
end

get "/:ability/edit" do
  check_sign_in_status
  selected_character = load_character_data

  @ability = params[:ability]
  @value = selected_character["abilities"][@ability]

  erb :edit_ability
end

post "/:ability/edit" do
  check_sign_in_status

  updated_value = params[:newvalue].to_i

  all_characters = load_character_file
  selected_character = all_characters[session[:username]][session[:char]]

  @abilities = selected_character["abilities"]
  @abilities[params[:ability]] = updated_value


  File.open("characters.yml", 'w+') do |f|
    f.write(all_characters.to_yaml)
  end

  redirect "/"
end

################# Dice Routes ##################

get "/dicerolls" do
  check_sign_in_status

  erb :dice, layout: :layout
end

get "/roll" do
  check_sign_in_status

  sides = params[:sides].to_i
  modifier = params[:modifier].to_i
  dicenumber = params[:dicenumber].to_i

  total = []

  dicenumber.times do
    total << rand(1..sides)
  end

  total << modifier

  session[:message] = breakout_roll_message(total)
  redirect "/dicerolls"
end

