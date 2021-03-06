require 'spec_helper'
require 'rails_helper'
require_relative '../support/feature_test_helper'

RSpec.describe "User Creates Visit", type: :feature do
  before do
    Rails.application.env_config['omniauth.auth'] = OmniAuth.config.mock_auth[:facebook]
    register_new_facebook_user

    Geocoder.configure(:lookup => :test)

    geocoder_stubs = [
      ['11211', 40.7093358, -73.9565551],
      ['11221', 40.6903213, -73.9271644],
      ['10012', 40.7250632, -73.9976946],
      ['07097', 40.7548065, -74.0681987],
      ['63130', 38.6682669, -90.3230806]
    ]
    geocoder_stubs.each do |stub|
      Geocoder::Lookup::Test.add_stub(
        stub[0], [{'latitude' => stub[1], 'longitude' => stub[2]}]
      )
    end
  end

  scenario "creating a new visit with no available hosts" do
    create_visit
    expect(page).to have_content('Nobody here, yet.')
  end

  scenario "missing fields in new visit form" do
    click_link 'Find A Host'
    click_button 'Contact Hosts'

    expect(page).to have_content('Start date is not a valid date')
  end

  scenario "creating a new visit with available hosts" do
    FactoryGirl.create(:user, phone: '2345678901')
    FactoryGirl.create :hosting,
      zipcode: '11211', max_guests: 10, host_id: User.last.id
    create_visit(Date.current, Date.current + 1.days)

    expect(page).to have_content('Hosts near 11211')
  end

  describe "sorting available hosts on visit results" do
    before(:each) do
      FactoryGirl.create(:user, phone: '2345678901')
      FactoryGirl.create :hosting,
        zipcode: '11221', max_guests: 10, host_id: User.last.id

      FactoryGirl.create(:user, phone: '3456789012')
      FactoryGirl.create :hosting,
        zipcode: '11211', max_guests: 10, host_id: User.last.id

      FactoryGirl.create(:user, phone: '4567890123')
      FactoryGirl.create :hosting,
        zipcode: '10012', max_guests: 10, host_id: User.last.id

      create_visit(Date.current, Date.current + 1.days, "07097")
    end

    scenario "when no hosts have been contacted" do
      expect('10012').to appear_before('11211')
      expect('11211').to appear_before('11221')
    end

    scenario "when the furthest host has been contacted" do
      Hosting.first.increment(:contact_count).save

      expect('10012').to appear_before('11211')
      expect('11211').to appear_before('11221')
    end

    scenario "when the nearest host has been contacted" do
      Hosting.last.increment(:contact_count).save
      visit visit_url(Visit.last)

      expect('11211').to appear_before('11221')
      expect('11221').to appear_before('10012')
    end

    scenario "when two hosts have been contacted, once each" do
      Hosting.last.increment(:contact_count).save
      Hosting.find_by(zipcode: '11211').increment(:contact_count).save
      visit visit_url(Visit.last)

      expect('11221').to appear_before('10012')
      expect('10012').to appear_before('11211')
    end

    scenario "when two hosts have been contacted a different amount of times" do
      Hosting.last.increment(:contact_count, 2).save
      Hosting.find_by(zipcode: '11211').increment(:contact_count).save
      visit visit_url(Visit.last)

      expect('11221').to appear_before('11211')
      expect('11211').to appear_before('10012')
    end
  end

  scenario "creating a new international visit with available hosts" do
    FactoryGirl.create(:user, phone: '+46 234-567890')
    FactoryGirl.create(:hosting, zipcode: '11211', max_guests: 10, host_id: User.last.id)
    create_visit(Date.current, Date.current + 1.days)

    expect(page).to have_content('Hosts near 11211')
  end

  scenario "editing an existing visit" do
    FactoryGirl.create(:hosting, zipcode: '11221', max_guests: 10, host_id: User.last.id)
    create_visit(Date.current, Date.current + 1.days)
    visit user_url(User.last)
    click_link '11211'
    fill_in 'Where are you going?', with: '63130'
    click_button 'Contact Hosts'

    expect(page).to have_content('Nobody here, yet.')

    visit user_url(User.last)

    expect(page).to have_content('63130')
  end

  scenario "deleting an existing visit" do
    create_visit(Date.current, Date.current + 1.days)
    visit user_url(User.last)
    expect(page).to have_content('11211')

    visit edit_visit_url(Visit.last)
    click_link 'Delete'

    expect(page).to_not have_content('11211')
    expect(Visit.with_deleted.last).to_not be_nil
  end

  scenario "new host becomes available for visit" do
    create_visit(Date.current, Date.current + 1.days)
    FactoryGirl.create(:hosting, zipcode: '11221', max_guests: 10, host_id: User.last.id)

    expect(open_last_email).to have_body_text("#{User.last.first_name} just signed up")
  end
end
