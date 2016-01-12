# Tests to make sure an aborted guest checkout (which due to a bug in
# spree_auth_devise creates invalid nil addresses in the database) doesn't
# prevent a customer from checking out.
require 'spec_helper'

feature 'Aborted guest checkout', js: true do
  include_context 'checkout with product'

  let(:user) { create(:user) }

  before(:each) do
    Spree::Order.delete_all
    Spree::Address.delete_all

    add_mug_to_cart
    restart_checkout
    fill_in 'order_email', with: 'guest@example.com'
    click_button 'Continue' # On registration page
    expect(current_path).to match(/(checkout|address)$/)
  end

  scenario 'does not prevent later logged-in checkout when entering new addresses' do
    click_button 'Continue' # On address page (expecting failure)

    sign_in_to_cart!(user)
    click_button 'Continue' # On cart page

    expect(current_path).to eq(spree.checkout_state_path(:address))

    expect {
      fill_in_address(build(:fake_address), :bill)
      fill_in_address(build(:fake_address), :ship)

      complete_checkout
    }.to change{ Spree::Address.count }.by(4)

    expect(Spree::Order.last.state).to eq('complete')
  end

  scenario 'does not prevent logged-in checkout when reusing merged guest addresses' do
    fill_in_address(build(:fake_address), :bill)
    fill_in_address(build(:fake_address), :ship)
    click_button 'Continue' # On address page
    expect(current_path).to eq(spree.checkout_state_path(:delivery))

    guest_order = Spree::Order.last
    expect(guest_order.bill_address_id).not_to be_nil
    expect(guest_order.ship_address_id).not_to be_nil

    order = create(:order_with_line_items, user: user)
    old_bill = order.bill_address_id
    old_ship = order.ship_address_id

    sign_in_to_cart!(user)
    click_button 'Continue' # On cart page

    expect {
      select_checkout_address guest_order.bill_address_id, :bill
      select_checkout_address guest_order.ship_address_id, :ship
      click_button 'Continue' # On address page
      expect(current_path).to eq(spree.checkout_state_path(:delivery))
    }.not_to change{ Spree::Address.count }

    expect{ complete_checkout }.to change{ Spree::Address.count }.by(2)

    expect{ order.reload }.to raise_error(ActiveRecord::RecordNotFound)
    expect(guest_order.reload.state).to eq('complete')
  end
end
