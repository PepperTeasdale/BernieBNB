require 'spec_helper'
require 'rails_helper'
require_relative '../support/feature_test_helper'

RSpec.describe "User Signs Up With Facebook", type: :feature, js: true do
  before do
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:facebook]
  end

  scenario 'starts session' do
    authenticate_with_facebook

    expect(page).to have_content( t('information.moredetails') )
  end

  scenario 'completing registration information' do
    authenticate_with_facebook
    fill_in_user_details

    expect(page).to have_content( t('information.emailconfirmsent') )
  end

  scenario 'fill out registration information incorrectly' do
    authenticate_with_facebook
    fill_in t('questions.phonenumber'), with: '5555555556'
    click_button 'Confirm Email'

    expect(page).to have_content( t('errors.messages.blankfirstname') )
  end

  scenario 'confirming registration with email' do
    authenticate_with_facebook
    fill_in_user_details

    confirmation_token = User.last.confirm_token
    confirm_url =
      "http://localhost:3000/users/#{confirmation_token}/confirm_email"
    expect(open_last_email).to have_body_text(confirm_url)

    visit confirm_url
    expect(page).to have_content( t('information.findahost') )
  end

  scenario 'register, sign out, sign back in' do
    register_new_facebook_user
    click_link 'Sign Out'
    click_link 'Facebook'

    expect(page).to have_content( t('information.findahost') )
  end

  scenario 'delete account' do
    register_new_facebook_user
    click_link '« Profile'
    page.accept_alert 'Are you sure? This will permanently delete your account.' do
      click_button 'Delete Account'
    end
    expect(User.count).to be(0)
    expect(page).to have_content('Successfully deleted account')
  end

  scenario 'facebook fails' do
    OmniAuth.config.mock_auth[:facebook] = :invalid_credentials

    authenticate_with_facebook

    expect(page).to have_content( t('information.signin') )
  end
end
