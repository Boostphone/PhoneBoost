class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  #protect_from_forgery with: :exception

  before_action :log_session

  def index
    session.clear
  end

  def basic_info
    session.clear
  end

  def basic_info_submit
    session[:name] = params[:name]
    session[:date_of_birth] = params[:date_of_birth]
    redirect_to '/application/contact_info'
  end

  def contact_info
    @language_options = %w(English Spanish Mandarin Cantonese Vietnamese Russian Tagalog Other)
  end

  def contact_info_submit
    session[:home_phone_number] = params[:home_phone_number]
    session[:email] = params[:email]
    session[:home_address] = params[:home_address]
    session[:home_zip_code] = params[:home_zip_code]
    session[:home_city] = params[:home_city]
    session[:home_state] = params[:home_state]
    session[:primary_language] = params[:primary_language]
    redirect_to '/application/sex_and_ssn'
  end

  def sex_and_ssn
  end

  def sex_and_ssn_submit
    sex_field_name = params.select do |key, value|
      value == "on"
    end.keys.first
    sex = case sex_field_name
      when "Male"
        "M"
      when "Female"
        "F"
      else
        ""
    end
    session[:ssn] = params[:ssn]
    session[:sex] = sex
    redirect_to '/application/medical'
  end

  def medical
  end

  def medical_submit
    if params[:yes] == "on"
      session[:medi_cal_interest] = "on"
    end
    redirect_to '/application/interview'
  end

  def interview
  end

  def interview_submit
    selected_times = params.select do |key, value|
      value == "on"
    end.keys
    underscored_selections = selected_times.map do  |t|
      t.gsub("-","_")
    end
    underscored_selections.each do |selection|
      session["interview_#{selection}"] = 'Yes'
    end
    redirect_to '/application/household_question'
  end

  def household_question
  end

  def additional_household_member
  end

  def additional_household_member_submit
    sex_field_name = params.select do |key, value|
      value == "on"
    end.keys.first
    sex = case sex_field_name
      when "Male"
        "M"
      when "Female"
        "F"
      else
        ""
    end
    clean_date_of_birth = ""
    if params["their_date_of_birth"] != ""
      date_of_birth_array = params["their_date_of_birth"].split('/')
      birth_year = date_of_birth_array[2]
      if birth_year.length == 4
        clean_date_of_birth = date_of_birth_array[0..1].join('/') + "/#{birth_year[-2..-1]}"
      else
        clean_date_of_birth = params["their_date_of_birth"]
      end
    end
    session[:additional_household_members] ||= []
    name = if params["their_name"] == nil
             ""
           else
             params["their_name"]
           end
    ssn = if params["their_ssn"] == nil
             ""
           else
             params["their_ssn"]
           end
    hash_for_person = {
      name: name,
      date_of_birth: clean_date_of_birth,
      ssn: ssn,
      sex: sex
    }
    session[:additional_household_members] << hash_for_person
    redirect_to '/application/household_question'
  end

  def review_and_submit
  end

  def review_and_submit_submit
    input_for_calfresh_application = session.to_hash
    input_for_calfresh_application[:signature] = params["signature"]
    if session[:date_of_birth] != ""
      date_of_birth_array = session[:date_of_birth].split('/')
      birth_year = date_of_birth_array[2]
      if birth_year.length == 4
        input_for_calfresh_application[:date_of_birth] = date_of_birth_array[0..1].join('/') + "/#{birth_year[-2..-1]}"
      else
        input_for_calfresh_application[:date_of_birth] = session[:date_of_birth]
      end
      input_for_calfresh_application.delete('date_of_birth')
    end
    input_for_calfresh_application[:name_page3] = session[:name]
    input_for_calfresh_application[:ssn_page3] = session[:ssn]
    input_for_calfresh_application[:language_preference_reading] = session[:primary_language]
    input_for_calfresh_application[:language_preference_writing] = session[:primary_language]
    FillInPdfApplicationAndEmailItJob.perform_later(input_for_calfresh_application)
    redirect_to '/application/document_instructions'
  end

  def document_instructions
  end

  def confirmation
    @user_token = SecureRandom.hex
  end

  def document_question
    @user_token = SecureRandom.hex
  end

  def complete
  end

  def show_application
    send_file Calfresh::Application.new(params[:id]).signed_png_path
  end

  private
  def log_session
    session_data = session.to_hash.select do |k,v|
      ['_csrf_token', 'session_id'].include?(k) == false
    end
    puts session_data
  end
end
