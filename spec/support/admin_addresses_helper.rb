module AdminAddresses
  def visit_user_addresses(user)
    visit spree.admin_addresses_path(user_id: user.id)
    expect(page).to have_content(I18n.t(:new_address, scope: :address_book))

    expect_user_selection(user)
  end

  def visit_order_addresses(order)
    visit spree.admin_addresses_path(order_id: order.id)
    expect(page).to have_content(I18n.t(:new_address, scope: :address_book))

    expect_order_selection(order)
    expect_user_selection(order.user) if order.user
  end

  def expect_address_count(count)
    if count == 0
      expect{page.find('#addresses tbody tr')}.to raise_error(/CSS/i)
    else
      expect(page.all('#addresses tbody tr').count).to eq(count)
    end
  end

  # Expects the +user+ addresses to be selected on the page.
  def expect_user_selection(user)
    expect_selected(user.bill_address, :user, :bill)
    expect_selected(user.ship_address, :user, :ship)
  end

  # Expects the +order+ addresses to be selected on the page.
  # FIXME: Deduplicated addresses?  The address ID will be different.
  def expect_order_selection(order)
    expect_selected(order.bill_address, :order, :bill)
    expect_selected(order.ship_address, :order, :ship)
  end

  # Expects the +address+ to be selected on the page for the user or order
  # shipping or billing address.  If +address+ is nil, expects the given
  # category not to have a selected address.
  #   user_or_order - :user or :order
  #   bill_or_ship - :bill or :ship
  def expect_selected(address, user_or_order, bill_or_ship)
    group_selector = "//input[@type='radio' and @name='#{user_or_order}[#{bill_or_ship}_address_id]' and @checked]"
    item_selector = address_radio_selector(address, user_or_order, bill_or_ship)

    if address.nil?
      expect{page.find(:xpath, group_selector)}.to raise_error(/Unable to find xpath/i)
    else
      expect{page.find(:xpath, group_selector)}.not_to raise_error
      expect(page.find(item_selector)).to be_checked
    end
  end

  # Clicks on the given address's radio button for the given address type.
  #   user_or_order - :user or :order
  #   bill_or_ship - :bill or :ship
  def select_address(address, user_or_order, bill_or_ship)
    item_selector = address_radio_selector(address, user_or_order, bill_or_ship)
    page.find(item_selector).click
  end

  # Returns a CSS selector to find the given address's radio button.
  def address_radio_selector(address, user_or_order, bill_or_ship)
    "##{user_or_order}_#{bill_or_ship}_address_id_#{address.try(:id)}"
  end

  # Clicks on the address page's submit button.
  def submit_addresses
    click_button I18n.t(:update_default_addresses, scope: :address_book)
  end
end

RSpec.configure do |c|
  c.include AdminAddresses, type: :feature
end