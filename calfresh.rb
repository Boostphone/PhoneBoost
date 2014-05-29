require 'pdf_forms'
require 'securerandom'

module Calfresh
  FORM_FIELDS = { name: 'Text1 PG 1', \
    name_page3: 'Text3 PG 3', \
    home_address: 'Text4 PG 1', \
    home_city: 'Text5 PG 1', \
    home_state: 'Text6 PG 1', \
    home_zip_code: 'Text7 PG 1', \
    date: 'Text32 PG 1', \
    home_phone_number: 'Text12 PG 1', \
    email: 'Text13 PG 1', \
    date_of_birth: 'Text5 PG 3', \
    sex: 'Text6 PG 3', \
    ssn: 'Text3 PG 1', \
    ssn_page3: 'Text9 PG 3'
  }

  class ApplicationWriter
    def initialize
      @pdftk = PdfForms.new('pdftk')
    end

    def fill_out_form(input)
      base64_signature_blob = input[:signature]
      symbolized_key_input = symbolize_keys(input)
      validated_field_input = filter_input_for_valid_fields(symbolized_key_input)
      input_for_pdf_writer = map_input_to_pdf_field_names(validated_field_input)
      input_for_pdf_writer[FORM_FIELDS[:date]] = Date.today.strftime("%m/%d/%Y")
      input_for_pdf_writer['Check Box1 PG 3'] = "Yes"
      unique_key = SecureRandom.hex
      filled_in_form_path = "/tmp/application_#{unique_key}.pdf"
      @pdftk.fill_form('./calfresh_2pager.pdf', filled_in_form_path, input_for_pdf_writer)
      write_signature_png_to_tmp(base64_signature_blob, unique_key)
      convert_application_pdf_to_png_set(unique_key)
      add_signature_to_application(unique_key)
      Application.new(unique_key)
    end

    #private
    def filter_input_for_valid_fields(form_input_hash)
      form_input_hash.select do |human_readable_field_name, value|
        FORM_FIELDS.has_key?(human_readable_field_name)
      end
    end

    def map_input_to_pdf_field_names(form_input)
      new_hash = Hash.new
      form_input.each do |human_readable_field_name, value|
        new_hash[FORM_FIELDS[human_readable_field_name]] = value
      end
      new_hash
    end

    def write_signature_png_to_tmp(signature_blob, unique_key)
      system("echo #{signature_blob} | base64 --decode > /tmp/signature_#{unique_key}.png")
    end

    def convert_application_pdf_to_png_set(unique_key)
      system("convert -alpha deactivate -density 300 -depth 8 -quality 85 /tmp/application_#{unique_key}.pdf /tmp/application_#{unique_key}.png")
    end

    def add_signature_to_application(unique_key)
      system("composite -geometry +31+2700 /tmp/signature_#{unique_key}.png /tmp/application_#{unique_key}-0.png /tmp/application_#{unique_key}-0.png")
    end

    def symbolize_keys(hash)
      symbolized_hash = Hash.new
      hash.each { |key,value| symbolized_hash[key.to_sym] = value }
      symbolized_hash
    end
  end

  class Application
    attr_reader :unique_key

    def initialize(unique_key)
      @unique_key = unique_key
    end

    def has_pngs?
      files_exist = true
      png_filenames.each do |filename|
        if File.exists?(filename) == false
          files_exist = false
        end
      end
      files_exist
    end

    def png_file_set
      file_array = Array.new
      png_filenames.each do |filename|
        file_array << File.new(filename)
      end
      file_array
    end

    def png_filenames
      filename_array = Array.new
      filename_array << "/tmp/application_#{@unique_key}-0.png"
      filename_array << "calfresh_application_images/page-8.png"
      filename_array << "/tmp/application_#{@unique_key}-1.png"
      (10..15).each do |page_number|
        filename_array << "calfresh_application_images/page-#{page_number}.png"
      end
      filename_array
    end

    def signed_png_path
      "/tmp/application_#{@unique_key}-0.png"
    end
  end

  class VerificationDocSet
    attr_reader :verification_docs

    def initialize(params)
      @verification_docs = filter_hash_for_doc_keys(params)
    end

    def filepath_array
      verification_docs.map { |doc_name, doc_hash| doc_hash[:tempfile].path }
    end

    def file_array
      filepath_array.map { |path| File.new(path) }
    end

    private
    def filter_hash_for_doc_keys(hash)
      hash.select do |key, value|
        ['identification', 'income', 'rent', 'utilities'].include?(key)
      end
    end
  end
end
