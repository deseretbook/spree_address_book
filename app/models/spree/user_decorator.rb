Spree.user_class.class_eval do
  has_many :addresses, -> { where(:deleted_at => nil).order("updated_at DESC") }, :class_name => 'Spree::Address'

  before_validation { uaddrcount(self.id ? self : nil, "U:B4VALIDATION") } # XXX
  before_save { uaddrcount(self.id ? self : nil, "U:B4SAVE") } # XXX
  after_save { uaddrcount(self.id ? self : nil, "U:AftSAVE"); whereami('U:AftSAVE') } # XXX

  before_validation :link_address

  # XXX / TODO: Probably want to get rid of this validation before deploying to
  # production because there is old invalid data. (Or override logic in gem
  # user to limit to new orders)
  validate :verify_address_owners

  # XXX
  # Validates that the default addresses are owned by the user.
  def verify_address_owners
    if bill_address && bill_address.user != self
      errors.add(:bill_address, "Billing address belongs to #{bill_address.user_id.inspect}, not to this user #{id.inspect}")
    end

    if ship_address && ship_address.user != self
      errors.add(:ship_address, "Shipping address belongs to #{ship_address.user_id.inspect}, not to this user #{id.inspect}")
    end
  end


  # Pre-validation hook that adds user_id to addresses that are assigned to the
  # user's default address slots.
  def link_address
    uaddrcount self.id && self, "U:la:b4(#{changes})" # XXX
    r = true

    puts "Bill present: #{self.bill_address.present?}" # XXX
    puts "Ship present: #{self.ship_address.present?}" # XXX

    if self.bill_address && !self.bill_address.user
      uaddrcount self.id && self, "U:la:bill(#{!self.bill_address.nil?}/#{self.bill_address.try(:id).inspect})" # XXX
      unless self.bill_address.editable?
        self.bill_address = self.bill_address.clone
      end
      self.bill_address.user = self
      r &= self.bill_address.save unless self.bill_address.new_record?
    end

    if self.ship_address && !self.ship_address.user
      uaddrcount self.id && self, "U:la:ship(#{!self.ship_address.nil?}/#{self.ship_address.try(:id).inspect})" # XXX
      unless self.ship_address.editable?
        self.ship_address = self.ship_address.clone
      end
      self.ship_address.user = self
      r &= self.ship_address.save unless self.ship_address.new_record?
    end

    uaddrcount self.id && self, "U:la:aft(#{r.inspect}/#{bill_address.try(:errors).try(:full_messages)}/#{ship_address.try(:errors).try(:full_messages)})" # XXX

    r
  end

  def save_default_addresses(billing, shipping, address)
    uaddrcount self, "U:sda:b4" # XXX
    # TODO: is this supposed to set both to the same address ID?
    r = update_attributes(bill_address_id: address.id) if billing.present?
    r &= update_attributes(ship_address_id: address.id) if shipping.present?
    uaddrcount self, "U:sda:aft(#{r.inspect}/#{errors.full_messages})" # XXX
    r
  end

  # This is the method that Spree calls when the user has requested that the
  # address be their default address. Spree makes a copy from the order. Instead
  # we just want to reference the address so we don't create extra address objects.
  def persist_order_address(order)
    uaddrcount self, "U:poa:b4", order: order # XXX
    r = update_attributes bill_address_id: order.bill_address_id

    # May not be present if delivery step has been removed
    r &= update_attributes ship_address_id: order.ship_address_id if order.ship_address
    uaddrcount self, "U:poa:aft(#{r.inspect}/#{errors.full_messages})", order: order # XXX
    r
  end

  # Returns true if this user's addresses can be edited or reassigned.  The
  # base implementation always returns true; users of the gem may override the
  # method to provide different behavior.  See also Spree::Address#editable?
  # and Spree::Order#can_update_addresses?
  def can_update_addresses?
    true
  end
end
