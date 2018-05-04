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

get "/choose" do
  @single_users_characters = load_character_file[session[:username]] || {}

  erb :choose
end

post "/choose" do
  session[:char] = params[:char]
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

