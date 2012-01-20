module Fog
  module Compute
    class IBM
      class Real

        # Create an address
        #
        # ==== Returns
        # * response<~Excon::Response>:
        #   * body<~Hash>
        # TODO: docs
        def create_address(location, offering_id, vlan_id=nil)
          request(
            :method   => 'POST',
            :expects  => 200,
            :path     => '/addresses',
            :body     => {
              'offeringID' => offering_id,
              'location'   => location,
              'vlanID'     => vlan_id
            }
          )
        end

      end
    end
  end
end
